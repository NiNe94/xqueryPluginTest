xquery version "1.0-ml";

module namespace csae-json-patient = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/patient";
import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";


declare function csae-json-patient:get-patient( $onset as xs:string, 
												$StudyId as xs:string, 
												$StudyEnvironment as xs:string, 
												$SubjectNumber as xs:string, 												
												$study-name as xs:string) as node()
{
	let $onset-date := xdmp:parse-yymmdd("dd MMM yyyy", $onset)
	let $demography := op:from-view("CSAE", "Demography")

	let $demo-set :=
		$demography
        => op:where(
				op:and(
                    op:eq(op:view-col("Demography", "StudyId"), $StudyId),
                    op:and(
                        op:eq(op:view-col("Demography", "StudyEnvironment"), $StudyEnvironment),
                        op:and(
							op:eq(op:view-col("Demography", "SubjectNumber"), $SubjectNumber),
							op:eq(op:view-col("Demography", "StudyName"), $study-name)
						)
                    )
                )					
        )
		=> op:select((
			"Sex",
		"DateOfBirth",
		"Ethnicity",
		"Asian",
		"AmericanIndian",
		"BlackOrAfrican",
		"NativeHawaiian",
		"White"))
		=> op:where-distinct()
		=> op:result()
	let $goc := <goc>{$demo-set}</goc>

	let $result := $goc/json:object
	let $sex := $result/json:entry[@key eq "CSAE.Demography.Sex"]/json:value/string()
	let $inactivationReason := $result/json:entry[@key eq "CSAE.AdverseEvent.InactivationReason"]/json:value/string()
	let $dateOfBirth := $result/json:entry[@key eq "CSAE.Demography.DateOfBirth"]/json:value/string()
	let $ethnicity := $result/json:entry[@key eq "CSAE.Demography.Ethnicity"]/json:value/string()
	let $asian := $result/json:entry[@key eq "CSAE.Demography.Asian"]/json:value/string()
	let $americanIndian := $result/json:entry[@key eq "CSAE.Demography.AmericanIndian"]/json:value/string()
	let $blackOrAfrican := $result/json:entry[@key eq "CSAE.Demography.BlackOrAfrican"]/json:value/string()
	let $nativeHawaiian := $result/json:entry[@key eq "CSAE.Demography.NativeHawaiian"]/json:value/string()
	let $white := $result/json:entry[@key eq "CSAE.Demography.White"]/json:value/string()
	let $patientAge := (sql:datediff('year', xdmp:parse-yymmdd("dd MMM yyyy", $dateOfBirth), $onset-date))

	let $vital-signs := op:from-view("CSAE", "VitalSigns")
	let $results :=
		$vital-signs
        => op:where(
				op:and(
                    op:eq(op:view-col("VitalSigns", "StudyId"), $StudyId),
                    op:and(
                        op:eq(op:view-col("VitalSigns", "StudyEnvironment"), $StudyEnvironment),
                        op:and(
							op:eq(op:view-col("VitalSigns", "SubjectNumber"), $SubjectNumber),
							op:eq(op:view-col("VitalSigns", "StudyName"), $study-name)
						)
                    )
                )					
        )		
		=> op:select((
			"VisitDate", 
			"Height", 
			"HeightUnit", 
			"Weight", 
			"WeightUnit", 
			"DataPageName"))
		=> op:where-distinct()
		=> op:result()
	let $doc := <doc>{$results}</doc>

	let $p := ()
	let $r := ()
	let $Weight := ()
	let $WeightUnit := ()
	let $Height := ()
	let $HeightUnit := ()
	let $dq-visit_date := ()

	let $selector :=
		for $result in $doc/json:object
		let $dq-visit_date := fn:true()
		let $src-visit-date := $result/json:entry[@key eq "CSAE.VitalSigns.VisitDate"]/json:value/string()
		let $visit-date := try {xdmp:parse-yymmdd("dd MMM yyyy", $src-visit-date)} catch ($e) {xdmp:set($dq-visit_date, fn:false())}
		let $onset-diff := if (fn:empty($visit-date)) then () else fn:abs(sql:datediff('day', $onset-date, $visit-date))
		return
			(
				if (($onset-diff lt $p or fn:empty($p)) and $dq-visit_date and ($result/json:entry[@key eq "CSAE.VitalSigns.Weight"]/json:value/string() ne ""))
				then (
					xdmp:set($p, $onset-diff),
					xdmp:set($Weight, $result/json:entry[@key eq "CSAE.VitalSigns.Weight"]/json:value/string()),
					xdmp:set($WeightUnit, $result/json:entry[@key eq "CSAE.VitalSigns.WeightUnit"]/json:value/string())
				)
				else (),

				if ($result/json:entry[@key eq "CSAE.VitalSigns.DataPageName"]/json:value/string() eq "Vital Signs (Screening)"
						and ($onset-diff lt $r or fn:empty($r)))
				then (

					(xdmp:set($r, $onset-diff),
					xdmp:set($Height, $result/json:entry[@key eq "CSAE.VitalSigns.Height"]/json:value/string()),
					xdmp:set($HeightUnit, if ($Height ne "") then $result/json:entry[@key eq "CSAE.VitalSigns.HeightUnit"]/json:value/string() else ""))

				)
				else ())


	let $subject := op:from-view("CSAE", "Subjects")

	let $subject-set :=
		$subject
        => op:where(
				op:and(
                    op:eq(op:view-col("Subjects", "StudyId"), $StudyId),
                    op:and(
                        op:eq(op:view-col("Subjects", "StudyEnvironment"), $StudyEnvironment),
                        op:and(
							op:eq(op:view-col("Subjects", "SubjectNumber"), $SubjectNumber),
							op:eq(op:view-col("Subjects", "StudyName"), $study-name)
						)
                    )
                )					
		)
		=> op:select(("Cohort"))
		=> op:result()
	let $soc := <doc>{$subject-set}</doc>
	let $sub := $soc/json:object

	let $patientCohort := $sub/json:entry[@key eq "CSAE.Subjects.Cohort"]/json:value/string()

	return
		object-node {
		"patientSubjectNumber" :
		object-node {
		"label" : "Subject Number",
		"value" : $SubjectNumber
		},
		if (fn:empty($patientCohort)) then () else "patientCohort" :
		object-node {
		"label" : "Actual Study Cohort",
		"value" : $patientCohort
		},
		"patientDateOfBirth" :
		object-node {
		"label" : "Date of Birth",
		"value" : $dateOfBirth
		},
		"patientAge" :
		object-node {
		"label" : "Age",
		"value" : $patientAge
		},
		"patientAgeUnit" :
		object-node {
		"label" : "Age Unit",
		"value" : "Years"
		},
		"patientGender" :
		object-node {
		"label" : "Sex",
		"value" : $sex
		},
		"patientEthnicity" :
		object-node {
		"label" : "Ethnicity",
		"value" : $ethnicity
		},
		if (fn:empty($asian)) then () else "patientAsian" :
		object-node {
		"label" : "Asian",
		"value" : $asian
		},
		if (fn:empty($americanIndian)) then () else "patientAmericanIndianAlaskaNative" :
		object-node {
		"label" : "American Indian or Alaska Native",
		"value" : $americanIndian
		},
		if (fn:empty($blackOrAfrican)) then () else "patientAfricanAmericanBlack" :
		object-node {
		"label" : "Black or African American",
		"value" : $blackOrAfrican
		},
		if (fn:empty($nativeHawaiian)) then () else "patientPacificIslandNativeHawaiian" :
		object-node {
		"label" : "Native Hawaiian Other Pacific Island",
		"value" : $nativeHawaiian
		},
		if (fn:empty($white)) then () else "patientWhite" :
		object-node {
		"label" : "White",
		"value" : $white
		},
		"patientHeight" :
		object-node {
		"label" : "Height",
		"value" : if (fn:empty($Height)) then "" else $Height
		},
		"patientHeightUnit" :
		object-node {
		"label" : "Height Unit",
		"value" : if (fn:empty($HeightUnit) or fn:empty($Height)) then "" else $HeightUnit
		},
		"patientWeight" :
		object-node {
		"label" : "Weight",
		"value" : $Weight
		},
		"patientWeightUnit" :
		object-node {
		"label" : "Weight unit",
		"value" : $WeightUnit
		}
		}
};






