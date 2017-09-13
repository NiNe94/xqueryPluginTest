xquery version "1.0-ml";

module namespace csae = "http://roche.com/data-capture-hub/saegeneration/lib/csae-json"; 
import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace csae-json-drug = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/drug" at "/saegeneration/lib/csae-json/drug.xqy";
import module namespace csae-json-medhistory = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/medhistory" at "/saegeneration/lib/csae-json/medhistory.xqy";
import module namespace csae-json-conmed = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/conmed" at "/saegeneration/lib/csae-json/conmed.xqy";
import module namespace csae-json-patient = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/patient" at "/saegeneration/lib/csae-json/patient.xqy";

(:~
 :  This function will return next version number for new JSON file
 :  parameters: 
 :		$StudyId, $SubjectNumber, $StudyEnvironment, $AeSeq - Primary key for AdverseEvent
 :	return:
 :		new version value
:)
declare function csae:get-version-number($StudyId as xs:string, 
                                         $SubjectNumber as xs:string, 
                                         $StudyEnvironment as xs:string, 
                                         $AeSeq as xs:string
) as xs:string
{

    let $max-version :=
        for $reported in cts:search(collection("saegeneration/saereports/reportsSent"), 
									cts:and-query( (cts:json-property-value-query("StudyId", $StudyId),
												    cts:json-property-value-query("SubjectNumber", $SubjectNumber),
													cts:json-property-value-query("StudyEnvironment", $StudyEnvironment),
												    cts:json-property-value-query("AeSeq", $AeSeq)													
									               )
												 )
									)
        order by $reported/headers/version/number() descending
        return $reported/headers/version/number()
    return if (fn:empty($max-version[1])) then "0" else ($max-version[1] + 1) cast as xs:string
};


(:~
 :  This function will return previously sent report to be able to compare and decide if follow-up is needed.
 :  parameters: 
 :		$StudyId, $SubjectNumber, $StudyEnvironment, $AeSeq - Primary key for AdverseEvent 
 :  return:
 :		latest reports with given Primary key
:)
declare function csae:get-latest-report($StudyId as xs:string, 
                                        $SubjectNumber as xs:string, 
                                        $StudyEnvironment as xs:string, 
                                        $AeSeq as xs:string)
{
 cts:search(fn:doc(),
  cts:and-query((
    cts:json-property-value-query("StudyId", $StudyId),
	cts:json-property-value-query("SubjectNumber", $SubjectNumber),
	cts:json-property-value-query("StudyEnvironment", $StudyEnvironment),
	cts:json-property-value-query("AeSeq", $AeSeq),
    cts:json-property-value-query("isCurrent", fn:true()),
    cts:collection-query("saegeneration/saereports/reportsSent")
   ))
   )

};


(:~
 :  This function will return only these PKs records that meet reportable criteria
 :   - for this version Reportable = "Y"
 :  return:
 :  	Primary keys where Reportable = "Y"
 :
:)
declare function csae:reportable-events()
{
    let $adverseevent := op:from-view("CSAE", "AdverseEvent")

    let $PKs := $adverseevent
    => op:where(op:eq(op:view-col("AdverseEvent", "Reportable"), "Y"))
    => op:select(("StudyId", "StudyEnvironment", "SubjectNumber", "AeSeq"))
    => op:where-distinct()
    => op:result()

	(: operator "/*" gives list of all elements on current level (it might be elements of and JSON array or single JSON element) :)
	(: operator "!" is XPATH/XQUERY 3.0 looping operator https://www.w3.org/TR/xpath-30/#id-map-operator :)
	(: https://developer.marklogic.com/blog/simple-mapping-operator	 :)	
    let $nodes := xdmp:to-json($PKs)
    let $iterated_nodes := $nodes/* !fn:string-join(./*,"|")

    return $iterated_nodes
};


(:~
 :  This function will return a generated AE JSON report for particular AE ID)
 :
 :  parameters:
 :		$StudyId, $SubjectNumber, $StudyEnvironment, $AeSeq - Primary key for AdverseEvent 
 :  return                   
 :		JSON report for a particular unique PK for an adverse event
 :
:)
declare function csae:report-generation(
		$StudyId as xs:string,
		$StudyEnvironment as xs:string,
		$SubjectNumber as xs:string,
		$AeSeq as xs:string
)
{
    let $pregnancy := op:from-view("CSAE", "Pregnancy")
    let $site := op:from-view("CSAE", "Sites")
    let $subject := op:from-view("CSAE", "Subjects")
    let $demography := op:from-view("CSAE", "Demography")
    let $vitalSigns := op:from-view("CSAE", "VitalSigns")
    let $adverseEvent := op:from-view("CSAE", "AdverseEvent")
    let $results :=
        $adverseEvent
        => op:join-left-outer(
                $pregnancy,
                (
                  op:on(
                      op:view-col("AdverseEvent", "StudyId"),
                      op:view-col("Pregnancy", "StudyId")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "StudyEnvironment"),
                      op:view-col("Pregnancy", "StudyEnvironment")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "SubjectNumber"),
                      op:view-col("Pregnancy", "SubjectNumber")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "AeSeq"),
                      op:view-col("Pregnancy", "AeSeq")
                  )					
                )
        )
        => op:join-left-outer(
                $subject,
                (
                  op:on(
                      op:view-col("AdverseEvent", "StudyId"),
                      op:view-col("Subjects", "StudyId")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "StudyEnvironment"),
                      op:view-col("Subjects", "StudyEnvironment")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "SubjectNumber"),
                      op:view-col("Subjects", "SubjectNumber")
                  )
                )				
        )
        => op:join-left-outer(
                $demography,
                (
                  op:on(
                      op:view-col("AdverseEvent", "StudyId"),
                      op:view-col("Demography", "StudyId")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "StudyEnvironment"),
                      op:view-col("Demography", "StudyEnvironment")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "SubjectNumber"),
                      op:view-col("Demography", "SubjectNumber")
                  )
                )				
        )
        => op:join-left-outer(
                $vitalSigns,
                (
                  op:on(
                      op:view-col("AdverseEvent", "StudyId"),
                      op:view-col("VitalSigns", "StudyId")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "StudyEnvironment"),
                      op:view-col("VitalSigns", "StudyEnvironment")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "SubjectNumber"),
                      op:view-col("VitalSigns", "SubjectNumber")
                  )
                )					
        )
        => op:join-left-outer(
                $site,
                (
                  op:on(
                      op:view-col("AdverseEvent", "StudyId"),
                      op:view-col("Sites", "StudyId")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "StudyEnvironment"),
                      op:view-col("Sites", "StudyEnvironment")
                  ),
                  op:on(
                      op:view-col("AdverseEvent", "SubjectNumber"),
                      op:view-col("Sites", "SubjectNumber")
                  )
                )						
        )
        => op:where(
                op:and(
                      op:eq(op:view-col("AdverseEvent", "StudyId"), $StudyId),
                      op:and(
                            op:eq(op:view-col("AdverseEvent", "StudyEnvironment"), $StudyEnvironment),
                             op:and(
                                  op:eq(op:view-col("AdverseEvent", "SubjectNumber"), $SubjectNumber),
                                  op:eq(op:view-col("AdverseEvent", "AeSeq"), $AeSeq)
                                  )
                            )
                      )
               )
        )	
        => op:select((
        op:view-col("AdverseEvent", "SubjectName"),
        op:view-col("AdverseEvent", "StudyId"),
        op:view-col("AdverseEvent", "StudyEnvironment"),
        op:view-col("AdverseEvent", "SubjectNumber"),
        op:view-col("AdverseEvent", "Reportable"),
        op:view-col("AdverseEvent", "AeSeq"),
        op:view-col("AdverseEvent", "AeNumber"),
        op:view-col("AdverseEvent", "InactivationReason"),
        op:view-col("AdverseEvent", "AeType"),
        op:view-col("AdverseEvent", "EventTerm"),
        op:view-col("AdverseEvent", "OnsetDateAe"),
        op:view-col("AdverseEvent", "AeConsideredAesiBecause"),
        op:view-col("AdverseEvent", "IntermittentAe"),
        op:view-col("AdverseEvent", "OutcomeAe"),
        op:view-col("AdverseEvent", "ResolutionDate"),
        op:view-col("AdverseEvent", "Death"),
        op:view-col("AdverseEvent", "DateOfDeath"),
        op:view-col("AdverseEvent", "AutopsyPerformed"),
        op:view-col("AdverseEvent", "LifeThreatening"),
        op:view-col("AdverseEvent", "Hospitalization"),
        op:view-col("AdverseEvent", "DateHospitalAdmit"),
        op:view-col("AdverseEvent", "DateHospitalDischarge"),
        op:view-col("AdverseEvent", "Disabling"),
        op:view-col("AdverseEvent", "OtherCriterion"),
        op:view-col("AdverseEvent", "BirthDefect"),
        op:view-col("AdverseEvent", "InitialNciCtcAeGrade"),
        op:view-col("AdverseEvent", "ExtremeNciCtcAeGrade"),
        op:view-col("AdverseEvent", "AeTreatmentMedication"),
        op:view-col("AdverseEvent", "AeTreatmentProcedure"),
        op:view-col("AdverseEvent", "SubjectDiscontinuedDueToAe"),
        op:view-col("AdverseEvent", "RelevantDiagnosticTests"),
        op:view-col("AdverseEvent", "AdditionalDetails1"),
        op:view-col("AdverseEvent", "AdditionalDetails2"),
        op:view-col("AdverseEvent", "AdditionalDetails3"),
        op:view-col("AdverseEvent", "AdditionalDetails4"),
        op:view-col("AdverseEvent","DoseLimitingToxicity"),
        op:view-col("AdverseEvent","OccurredDuringTimepoint"),
        op:view-col("AdverseEvent","IsDeviceInterventionRequired"),
        op:view-col("AdverseEvent","NyhaClass"),
        op:view-col("AdverseEvent", "Pathogen"),
        op:view-col("AdverseEvent","PathogenCode"),
        op:view-col("AdverseEvent","InitialAeIntensity"),
        op:view-col("AdverseEvent","InitialWhoToxicGrade"),
        op:view-col("AdverseEvent","ExtremeAeIntensity"),
        op:view-col("AdverseEvent","ExtremeWhoToxicGrade"),
        op:view-col("AdverseEvent","ReportingReason"),
        op:view-col("AdverseEvent", "StudyName"),
        op:view-col("Sites", "SiteName"),
        op:view-col("Sites", "SiteNumber"),
		op:view-col("Sites", "Country"),
        op:view-col("Subjects","RandomizationDate"),
        op:view-col("Subjects","SubjectDispositionDate"),
        op:view-col("Subjects","ReasonSubjectDisposition"),
		op:view-col("Subjects","InvestigatorName"),
        op:view-col("Demography","Sex"),
        op:view-col("Demography","DateOfBirth"),
        op:view-col("Demography","Ethnicity"),
        op:view-col("Demography","Asian"),
        op:view-col("Demography","AmericanIndian"),
        op:view-col("Demography","BlackOrAfrican"),
        op:view-col("Demography","NativeHawaiian"),
        op:view-col("Demography","White"),
        op:view-col("VitalSigns","Weight"),
        op:view-col("VitalSigns","WeightUnit"),
        op:view-col("VitalSigns","Height"),
        op:view-col("VitalSigns","HeightUnit"),
        op:view-col("Pregnancy","PregnancyReportDate"),
        op:view-col("Pregnancy","PrenatalCare"),
        op:view-col("Pregnancy","WeeksatExposure"),
        op:view-col("Pregnancy","WeeksatExposureUnit"),
        op:view-col("Pregnancy","ReproductiveHistoryPara"),
        op:view-col("Pregnancy","FirstDayLastMenstrualPeriod"),
        op:view-col("Pregnancy","AmniocentesisResult"),
        op:view-col("Pregnancy","CvsResult"),
        op:view-col("Pregnancy","EstimatedDateofDelivery"),
        op:view-col("Pregnancy","ReproductiveHistoryGravida"),
        op:view-col("Pregnancy","UltrasoundResult"),
        op:view-col("Pregnancy","TestPerfDurPregAmnio"),
        op:view-col("Pregnancy","TestPerfDurPregCvs"),
        op:view-col("Pregnancy","TestPerfDurPregNone"),
        op:view-col("Pregnancy","TestPerfDurPregUltrasd"),
        op:view-col("Pregnancy","TestPerfDurPregUnk"),
        op:view-col("Pregnancy","PregnancyOccuredIn"),
        op:view-col("Pregnancy","PartnerSpouseAuthConcent"),
        op:view-col("Pregnancy","PregnancyNumber"),
        op:view-col("Pregnancy","NumberofSpontaneousAbortions"),
        op:view-col("Pregnancy","NumberofTherapeuticAbortions"),
        op:view-col("Pregnancy","HealthCareProfessionalAddress"),
        op:view-col("Pregnancy","HealthCareProfessionaleMail"),
        op:view-col("Pregnancy","HealthCareProfessionalFax"),
        op:view-col("Pregnancy","HealthCareProfessionalName"),
        op:view-col("Pregnancy","HealthCareProfessionalPhone"),
        op:view-col("Pregnancy","TpalNumberAbortion"),
        op:view-col("Pregnancy","TpalNumberLive"),
        op:view-col("Pregnancy","TpalNumberPreterm"),
        op:view-col("Pregnancy","TpalNumberTerm"),
        op:view-col("Pregnancy","PregnancyWasInterrupted1"),
        op:view-col("Pregnancy","ApgarScore1Min1"),
        op:view-col("Pregnancy","ApgarScore5Min1"),
        op:view-col("Pregnancy","DeliveryDate1"),
        op:view-col("Pregnancy","PregnancyOutcome1"),
        op:view-col("Pregnancy","InfantOutcomeInformation1"),
        op:view-col("Pregnancy","InfantSex1"),
        op:view-col("Pregnancy","HeadCircumference1"),
        op:view-col("Pregnancy","HeadCircumferenceUnit1"),
        op:view-col("Pregnancy","Length1"),
        op:view-col("Pregnancy","LengthUnit1"),
        op:view-col("Pregnancy","Weight1"),
        op:view-col("Pregnancy","WeightUnit1"),
        op:view-col("Pregnancy","GestationalBirthAge1"),
        op:view-col("Pregnancy","PregnancyInterruptedSpecify1"),
        op:view-col("Pregnancy","DateofTermination1"),
        op:view-col("Pregnancy","PregnancyWasInterrupted2"),
        op:view-col("Pregnancy","ApgarScore1Min2"),
        op:view-col("Pregnancy","ApgarScore5Min2"),
        op:view-col("Pregnancy","DeliveryDate2"),
        op:view-col("Pregnancy","PregnancyOutcome2"),
        op:view-col("Pregnancy","InfantOutcomeInformation2"),
        op:view-col("Pregnancy","InfantSex2"),
        op:view-col("Pregnancy","HeadCircumference2"),
        op:view-col("Pregnancy","HeadCircumferenceUnit2"),
        op:view-col("Pregnancy","Length2"),
        op:view-col("Pregnancy","LengthUnit2"),
        op:view-col("Pregnancy","Weight2"),
        op:view-col("Pregnancy","WeightUnit2"),
        op:view-col("Pregnancy","GestationalBirthAge2"),
        op:view-col("Pregnancy","PregnancyInterruptedSpecify2"),
        op:view-col("Pregnancy","DateofTermination2"),
        op:view-col("Pregnancy","NotApplicableBabyNumber2")
        ))
        => op:limit(1)
        => op:result()


    (: Make the output of the Optic API XML :)
    let $doc := <doc>{$results}</doc>
    (: Iterate through each result :)
    for $result in $doc/json:object
    let $subjectName := $result/json:entry[@key eq "CSAE.AdverseEvent.SubjectName"]/json:value/string()
			
    (: Get the drug map :)
    let $drugMap := csae-json-drug:get-map($StudyId, $StudyEnvironment, $SubjectNumber)
    (: Get the medhisotry map :)
    let $medHistoryMap := csae-json-medhistory:get-map($StudyId, $StudyEnvironment, $SubjectNumber)
    (: Get the conmed map :)
    let $conMedMap := csae-json-conmed:get-map($StudyId, $StudyEnvironment, $SubjectNumber)
    let $reportable := $result/json:entry[@key eq "CSAE.AdverseEvent.Reportable"]/json:value/string()
    let $aeNumber := $result/json:entry[@key eq "CSAE.AdverseEvent.AeNumber"]/json:value/string()

	(: StudyId, SubjectNumber, studyEnvironment, AeSeq are together PK of AdverseEvent :)	
    let $StudyId := $result/json:entry[@key eq "CSAE.AdverseEvent.StudyId"]/json:value/string()	
    let $SubjectNumber := $result/json:entry[@key eq "CSAE.AdverseEvent.SubjectNumber"]/json:value/string()  
    let $studyEnvironment := $result/json:entry[@key eq "CSAE.AdverseEvent.StudyEnvironment"]/json:value/string()
    let $AeSeq := $result/json:entry[@key eq "CSAE.AdverseEvent.AeSeq"]/json:value/string()		
	
    let $aeType := $result/json:entry[@key eq "CSAE.AdverseEvent.AeType"]/json:value/string()
    let $eventTerm := $result/json:entry[@key eq "CSAE.AdverseEvent.EventTerm"]/json:value/string()
    let $onsetDate := $result/json:entry[@key eq "CSAE.AdverseEvent.OnsetDateAe"]/json:value/string()
    let $studyName := $result/json:entry[@key eq "CSAE.AdverseEvent.StudyName"]/json:value/string()
    let $siteName := $result/json:entry[@key eq "CSAE.Sites.SiteName"]/json:value/string()
    let $siteNumber := $result/json:entry[@key eq "CSAE.Sites.SiteNumber"]/json:value/string()
	let $country := $result/json:entry[@key eq "CSAE.Sites.Country"]/json:value/string()
    let $randomisationDate := $result/json:entry[@key eq "CSAE.Subjects.RandomizationDate"]/json:value/string()
    let $subjectDispositionDate := $result/json:entry[@key eq "CSAE.Subjects.SubjectDispositionDate"]/json:value/string()
    let $reasonSubjectDisposition := $result/json:entry[@key eq "CSAE.Subjects.ReasonSubjectDisposition"]/json:value/string()
    let $investigatorName := $result/json:entry[@key eq "CSAE.Subjects.InvestigatorName"]/json:value/string()
    let $sex := $result/json:entry[@key eq "CSAE.Demography.Sex"]/json:value/string()
    let $inactivationReason := $result/json:entry[@key eq "CSAE.AdverseEvent.InactivationReason"]/json:value/string()
    let $dateOfBirth := $result/json:entry[@key eq "CSAE.Demography.DateOfBirth"]/json:value/string()
    let $ethnicity := $result/json:entry[@key eq "CSAE.Demography.Ethnicity"]/json:value/string()
    let $asian := $result/json:entry[@key eq "CSAE.Demography.Asian"]/json:value/string()
    let $americanIndian := $result/json:entry[@key eq "CSAE.Demography.AmericanIndian"]/json:value/string()
    let $blackOrAfrican := $result/json:entry[@key eq "CSAE.Demography.BlackOrAfrican"]/json:value/string()
    let $nativeHawaiian := $result/json:entry[@key eq "CSAE.Demography.NativeHawaiian"]/json:value/string()
    let $white := $result/json:entry[@key eq "CSAE.Demography.White"]/json:value/string()
    let $aeConsideredAesiBecause := $result/json:entry[@key eq "CSAE.AdverseEvent.AeConsideredAesiBecause"]/json:value/string()
    let $intermittentAe := $result/json:entry[@key eq "CSAE.AdverseEvent.IntermittentAe"]/json:value/string()
    let $outcomeAe := $result/json:entry[@key eq "CSAE.AdverseEvent.OutcomeAe"]/json:value/string()
    let $resolutionDate := $result/json:entry[@key eq "CSAE.AdverseEvent.ResolutionDate"]/json:value/string()
    let $death := $result/json:entry[@key eq "CSAE.AdverseEvent.Death"]/json:value/string()
    let $dateOfDeath := $result/json:entry[@key eq "CSAE.AdverseEvent.DateOfDeath"]/json:value/string()
    let $autopsyPerformed := $result/json:entry[@key eq "CSAE.AdverseEvent.AutopsyPerformed"]/json:value/string()
    let $lifeThreatening := $result/json:entry[@key eq "CSAE.AdverseEvent.LifeThreatening"]/json:value/string()
    let $hospitalization := $result/json:entry[@key eq "CSAE.AdverseEvent.Hospitalization"]/json:value/string()
    let $dateHospitalAdmit := $result/json:entry[@key eq "CSAE.AdverseEvent.DateHospitalAdmit"]/json:value/string()
    let $dateHospitalDischarge := $result/json:entry[@key eq "CSAE.AdverseEvent.DateHospitalDischarge"]/json:value/string()
    let $disabling := $result/json:entry[@key eq "CSAE.AdverseEvent.Disabling"]/json:value/string()
    let $birthDefect := $result/json:entry[@key eq "CSAE.AdverseEvent.BirthDefect"]/json:value/string()
    let $otherCriterion := $result/json:entry[@key eq "CSAE.AdverseEvent.OtherCriterion"]/json:value/string()
    let $initialNciCtcAeGrade := $result/json:entry[@key eq "CSAE.AdverseEvent.InitialNciCtcAeGrade"]/json:value/string()
    let $extremeNciCtcAeGrade := $result/json:entry[@key eq "CSAE.AdverseEvent.ExtremeNciCtcAeGrade"]/json:value/string()
    let $aeTreatmentMedication := $result/json:entry[@key eq "CSAE.AdverseEvent.AeTreatmentMedication"]/json:value/string()
    let $aeTreatmentProcedure := $result/json:entry[@key eq "CSAE.AdverseEvent.AeTreatmentProcedure"]/json:value/string()
    let $subjectDiscontinuedDueToAe := $result/json:entry[@key eq "CSAE.AdverseEvent.SubjectDiscontinuedDueToAe"]/json:value/string()
    let $relevantDiagnosticTests := $result/json:entry[@key eq "CSAE.AdverseEvent.RelevantDiagnosticTests"]/json:value/string()
    let $additionalDetails1 := $result/json:entry[@key eq "CSAE.AdverseEvent.AdditionalDetails1"]/json:value/string()
    let $additionalDetails2 := $result/json:entry[@key eq "CSAE.AdverseEvent.AdditionalDetails2"]/json:value/string()
    let $additionalDetails3 := $result/json:entry[@key eq "CSAE.AdverseEvent.AdditionalDetails3"]/json:value/string()
    let $additionalDetails4 := $result/json:entry[@key eq "CSAE.AdverseEvent.AdditionalDetails4"]/json:value/string()
    let $height := $result/json:entry[@key eq "CSAE.VitalSigns.Height"]/json:value/string()
    let $heightUnit := $result/json:entry[@key eq "CSAE.VitalSigns.HeightUnit"]/json:value/string()
    let $weight := $result/json:entry[@key eq "CSAE.VitalSigns.Weight"]/json:value/string()
    let $weightUnit := $result/json:entry[@key eq "CSAE.VitalSigns.WeightUnit"]/json:value/string()
	let $version := csae:get-version-number($result/json:entry[@key eq "CSAE.AdverseEvent.StudyId"]/json:value/string()	,
											$result/json:entry[@key eq "CSAE.AdverseEvent.SubjectNumber"]/json:value/string(),  
											$result/json:entry[@key eq "CSAE.AdverseEvent.StudyEnvironment"]/json:value/string(),
											$result/json:entry[@key eq "CSAE.AdverseEvent.AeSeq"]/json:value/string())			
    let $pregnancyReportDate := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyReportDate"]/json:value/string()
	let $prenatalCare := $result/json:entry[@key eq "CSAE.Pregnancy.PrenatalCare"]/json:value/string()
	let $weeksatExposure := $result/json:entry[@key eq "CSAE.Pregnancy.WeeksatExposure"]/json:value/string()
	let $weeksatExposureUnit := $result/json:entry[@key eq "CSAE.Pregnancy.WeeksatExposureUnit"]/json:value/string()
	let $reproductiveHistoryPara := $result/json:entry[@key eq "CSAE.Pregnancy.ReproductiveHistoryPara"]/json:value/string()
	let $firstDayLastMenstrualPeriod := $result/json:entry[@key eq "CSAE.Pregnancy.FirstDayLastMenstrualPeriod"]/json:value/string()
	let $amniocentesisResult := $result/json:entry[@key eq "CSAE.Pregnancy.AmniocentesisResult"]/json:value/string()
	let $cvsResult := $result/json:entry[@key eq "CSAE.Pregnancy.CvsResult"]/json:value/string()
	let $estimatedDateofDelivery := $result/json:entry[@key eq "CSAE.Pregnancy.EstimatedDateofDelivery"]/json:value/string()
	let $reproductiveHistoryGravida := $result/json:entry[@key eq "CSAE.Pregnancy.ReproductiveHistoryGravida"]/json:value/string()
	let $ultrasoundResult := $result/json:entry[@key eq "CSAE.Pregnancy.UltrasoundResult"]/json:value/string()
	let $testPerfDurPregAmnio := $result/json:entry[@key eq "CSAE.Pregnancy.TestPerfDurPregAmnio"]/json:value/string()
	let $testPerfDurPregCvs := $result/json:entry[@key eq "CSAE.Pregnancy.TestPerfDurPregCvs"]/json:value/string()
	let $testPerfDurPregNone := $result/json:entry[@key eq "CSAE.Pregnancy.TestPerfDurPregNone"]/json:value/string()
	let $testPerfDurPregUltrasd := $result/json:entry[@key eq "CSAE.Pregnancy.TestPerfDurPregUltrasd"]/json:value/string()
	let $testPerfDurPregUnk := $result/json:entry[@key eq "CSAE.Pregnancy.TestPerfDurPregUnk"]/json:value/string()
	let $pregnancyOccuredIn := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyOccuredIn"]/json:value/string()
	let $partnerSpouseAuthConcent := $result/json:entry[@key eq "CSAE.Pregnancy.PartnerSpouseAuthConcent"]/json:value/string()
	let $pregnancyNumber := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyNumber"]/json:value/string()
	let $numberofSpontaneousAbortions := $result/json:entry[@key eq "CSAE.Pregnancy.NumberofSpontaneousAbortions"]/json:value/string()
	let $numberofTherapeuticAbortions := $result/json:entry[@key eq "CSAE.Pregnancy.NumberofTherapeuticAbortions"]/json:value/string()
	let $healthCareProfessionalAddress := $result/json:entry[@key eq "CSAE.Pregnancy.HealthCareProfessionalAddress"]/json:value/string()
	let $healthCareProfessionaleMail := $result/json:entry[@key eq "CSAE.Pregnancy.HealthCareProfessionaleMail"]/json:value/string()
	let $healthCareProfessionalFax := $result/json:entry[@key eq "CSAE.Pregnancy.HealthCareProfessionalFax"]/json:value/string()
	let $healthCareProfessionalName := $result/json:entry[@key eq "CSAE.Pregnancy.HealthCareProfessionalName"]/json:value/string()
	let $healthCareProfessionalPhone := $result/json:entry[@key eq "CSAE.Pregnancy.HealthCareProfessionalPhone"]/json:value/string()
	let $tpalNumberAbortion := $result/json:entry[@key eq "CSAE.Pregnancy.TpalNumberAbortion"]/json:value/string()
	let $tpalNumberLive := $result/json:entry[@key eq "CSAE.Pregnancy.TpalNumberLive"]/json:value/string()
	let $tpalNumberPreterm := $result/json:entry[@key eq "CSAE.Pregnancy.TpalNumberPreterm"]/json:value/string()
	let $tpalNumberTerm := $result/json:entry[@key eq "CSAE.Pregnancy.TpalNumberTerm"]/json:value/string()
	let $pregnancyWasInterrupted1 := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyWasInterrupted1"]/json:value/string()
	let $apgarScore1Min1 := $result/json:entry[@key eq "CSAE.Pregnancy.ApgarScore1Min1"]/json:value/string()
	let $apgarScore5Min1 := $result/json:entry[@key eq "CSAE.Pregnancy.ApgarScore5Min1"]/json:value/string()
	let $deliveryDate1 := $result/json:entry[@key eq "CSAE.Pregnancy.DeliveryDate1"]/json:value/string()
	let $pregnancyOutcome1 := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyOutcome1"]/json:value/string()
	let $infantOutcomeInformation1 := $result/json:entry[@key eq "CSAE.Pregnancy.InfantOutcomeInformation1"]/json:value/string()
	let $infantSex1 := $result/json:entry[@key eq "CSAE.Pregnancy.InfantSex1"]/json:value/string()
	let $headCircumference1 := $result/json:entry[@key eq "CSAE.Pregnancy.HeadCircumference1"]/json:value/string()
	let $headCircumferenceUnit1 := $result/json:entry[@key eq "CSAE.Pregnancy.HeadCircumferenceUnit1"]/json:value/string()
	let $length1 := $result/json:entry[@key eq "CSAE.Pregnancy.Length1"]/json:value/string()
	let $lengthUnit1 := $result/json:entry[@key eq "CSAE.Pregnancy.LengthUnit1"]/json:value/string()
	let $weight1 := $result/json:entry[@key eq "CSAE.Pregnancy.Weight1"]/json:value/string()
	let $weightUnit1 := $result/json:entry[@key eq "CSAE.Pregnancy.WeightUnit1"]/json:value/string()
	let $gestationalBirthAge1 := $result/json:entry[@key eq "CSAE.Pregnancy.GestationalBirthAge1"]/json:value/string()
	let $pregnancyInterruptedSpecify1 := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyInterruptedSpecify1"]/json:value/string()
	let $dateofTermination1 := $result/json:entry[@key eq "CSAE.Pregnancy.DateofTermination1"]/json:value/string()
	let $pregnancyWasInterrupted2 := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyWasInterrupted2"]/json:value/string()
	let $apgarScore1Min2 := $result/json:entry[@key eq "CSAE.Pregnancy.ApgarScore1Min2"]/json:value/string()
	let $apgarScore5Min2 := $result/json:entry[@key eq "CSAE.Pregnancy.ApgarScore5Min2"]/json:value/string()
	let $deliveryDate2 := $result/json:entry[@key eq "CSAE.Pregnancy.DeliveryDate2"]/json:value/string()
	let $pregnancyOutcome2 := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyOutcome2"]/json:value/string()
	let $infantOutcomeInformation2 := $result/json:entry[@key eq "CSAE.Pregnancy.InfantOutcomeInformation2"]/json:value/string()
	let $infantSex2 := $result/json:entry[@key eq "CSAE.Pregnancy.InfantSex2"]/json:value/string()
	let $headCircumference2 := $result/json:entry[@key eq "CSAE.Pregnancy.HeadCircumference2"]/json:value/string()
	let $headCircumferenceUnit2 := $result/json:entry[@key eq "CSAE.Pregnancy.HeadCircumferenceUnit2"]/json:value/string()
	let $length2 := $result/json:entry[@key eq "CSAE.Pregnancy.Length2"]/json:value/string()
	let $lengthUnit2 := $result/json:entry[@key eq "CSAE.Pregnancy.LengthUnit2"]/json:value/string()
	let $weight2 := $result/json:entry[@key eq "CSAE.Pregnancy.Weight2"]/json:value/string()
	let $weightUnit2 := $result/json:entry[@key eq "CSAE.Pregnancy.WeightUnit2"]/json:value/string()
	let $gestationalBirthAge2 := $result/json:entry[@key eq "CSAE.Pregnancy.GestationalBirthAge2"]/json:value/string()
	let $pregnancyInterruptedSpecify2 := $result/json:entry[@key eq "CSAE.Pregnancy.PregnancyInterruptedSpecify2"]/json:value/string()
	let $dateofTermination2 := $result/json:entry[@key eq "CSAE.Pregnancy.DateofTermination2"]/json:value/string()
	let $notApplicableBabyNumber2 := $result/json:entry[@key eq "CSAE.Pregnancy.NotApplicableBabyNumber2"]/json:value/string()
    let $doseLimitingToxicity := $result/json:entry[@key eq "CSAE.AdverseEvent.DoseLimitingToxicity"]/json:value/string()
    let $occurredDuringTimepoint := $result/json:entry[@key eq "CSAE.AdverseEvent.OccurredDuringTimepoint"]/json:value/string()
    let $isDeviceInterventionRequired := $result/json:entry[@key eq "CSAE.AdverseEvent.IsDeviceInterventionRequired"]/json:value/string()
    let $nyhaClass := $result/json:entry[@key eq "CSAE.AdverseEvent.NyhaClass"]/json:value/string()
    let $pathogen := $result/json:entry[@key eq "CSAE.AdverseEvent.Pathogen"]/json:value/string()    
    let $pathogenCode := $result/json:entry[@key eq "CSAE.AdverseEvent.PathogenCode"]/json:value/string()
    let $initialAeIntensity := $result/json:entry[@key eq "CSAE.AdverseEvent.InitialAeIntensity"]/json:value/string()
    let $initialWhoToxicGrade := $result/json:entry[@key eq "CSAE.AdverseEvent.InitialWhoToxicGrade"]/json:value/string()
    let $extremeAeIntensity := $result/json:entry[@key eq "CSAE.AdverseEvent.ExtremeAeIntensity"]/json:value/string()        
    let $extremeWhoToxicGrade := $result/json:entry[@key eq "CSAE.AdverseEvent.ExtremeWhoToxicGrade"]/json:value/string()
    let $reportingReason := $result/json:entry[@key eq "CSAE.AdverseEvent.ReportingReason"]/json:value/string()
        
    (:~ Build the JSON output
   : If one or more if checks is true report will be not genereated and sent.
   : You can add or remove contitions by editing if ( <expr> )
   :)

    return if (fn:not($subjectName) or fn:not($eventTerm) or (map:count($drugMap) = 0))
    then ()
    else (
            let $reportDocument :=
                object-node {
                "headers" : object-node {
                "reportStatus" : "READY",
                "StudyId": $StudyId,
                "SubjectNumber": $SubjectNumber,
                "StudyEnvironment": $studyEnvironment,
                "AeSeq": $AeSeq,				
                "version": $version,
                "isCurrent": fn:true()
                },
                "content" : object-node {
                "Report" : object-node {
                "General" : object-node {
                "generalReportId" : object-node {
                "label" : "Report Identifier",
                "value" : "DCH-1000000001"
                },
                "generalCaseUniqueId" : object-node {
                "label" : "Case Unique Identifier",
                "value" : "US-DCH-1234567890"
                },
                "generalAeNumber" : object-node {
                "label" : "AE Line Number",
                "value" : $aeNumber
                },
                "generalVersionNumber" : object-node {
                "label" : "Version Number",
                "value" : $version
                },
                "generalAeSenderIdentifier" : object-node {
                "label" : "AE Sender Identifier",
                "value" : "DCH"
                },
                "generalAeReceiverIdentifier" : object-node {
                "label" : "AE Receiver Identifier",
                "value" : "ROCHE"
                },
                "generalStudyNumber" : object-node {
                "label" : "Study Number",
                "value" : $studyName
                },
                "generalAeCountry" : object-node {
                "label" : "Country",
                "value" : $country
                },
                "generalReportingReason" : object-node {
                "label" : "Reporting Reason",
                "value" : $reportingReason
                },
                "generalDateReportGenerated" : object-node {
                "label" : "Date Report Generated",
                "value" : fn:format-dateTime(fn:current-dateTime(), "[D01]/[M01]/[Y0001] [H01]:[m01]", "en", "AD", "US")
                },
                "generalInactivationReason" : object-node {
                "label" : "Inactivation Reason",
                "value" : $inactivationReason
                }
                },

                (: Begining of Event JSON block :)
                "Event" : object-node {
                    "eventTerm" : object-node {
                        "label" : "Primary Adverse Event - Raw",
                        "value" : $eventTerm
                    },
                    "eventOnsetDateAe" : object-node {
                        "label" : "AE Onset Date",
                        "value" : $onsetDate
                    },
                    "eventAeNumber" : object-node {
                        "label" : "AE Line Number",
                        "value" : $aeNumber
                    },
                    "eventAEType" : object-node {
                        "label" : "AE Type (Non-serious/Serious)",
                        "value" : $aeType
                    },
                    "eventAeConsideredAesiBecause" : object-node {
                        "label" : "AE Considered AESI Because",
                        "value" : $aeConsideredAesiBecause
                    },
                    "eventIntermittentAe" : object-node {
                        "label" : "Intermittent AE",
                        "value" : $intermittentAe
                    },
                    "eventOutcomeAe" : object-node {
                        "label" : "AE Outcome",
                        "value" : $outcomeAe
                    },
                    "eventResolutionDate" : object-node {
                        "label" : "AE Resolution Date",
                        "value" : $resolutionDate
                    },
                    "eventDeath" : object-node {
                        "label" : "AE Serious - Death",
                        "value" : $death
                    },
                    "eventDateOfDeath" : object-node {
                        "label" : "Date of Death",
                        "value" : $dateOfDeath
                    },
                    "eventAutopsyPerformed" : object-node {
                        "label" : "Autopsy Performed",
                        "value" : $autopsyPerformed
                    },
                    "eventLifeThreatening" : object-node {
                        "label" : "AE Serious - Life Threatening",
                        "value" : $lifeThreatening
                    },
                    "eventHospitalization" : object-node {
                        "label" : "AE Serious - Inpatient Hospitalization",
                        "value" : $hospitalization
                    },
                    "eventDateHospitalAdmit" : object-node {
                        "label" : "Hospitalization Admin Date",
                        "value" : $dateHospitalAdmit
                    },
                    "eventDateHospitalDischarge" : object-node {
                        "label" : "Hospitalization Discharge Date",
                        "value" : $dateHospitalDischarge
                    },
                    "eventDisabling" : object-node {
                        "label" : "AE Serious - Disabling",
                        "value" : $disabling
                    },
                    "eventBirthDefect" : object-node {
                        "label" : "AE Serious - Birth Defect",
                        "value" : $birthDefect
                    },
                    "eventOtherCriterion" : object-node {
                        "label" : "AE Serious - Other Criterion",
                        "value" : $otherCriterion
                    },
                    "eventInitialNciCtcAeGrade" : object-node {
                        "label" : "AE Initial NCI-CTCAE Grade",
                        "value" : $initialNciCtcAeGrade
                    },
                    "eventExtremeNciCtcAeGrade" : object-node {
                        "label" : "AE Extreme NCI-CTCAE Grade",
                        "value" : $extremeNciCtcAeGrade
                    },
                    "eventAeTreatmentMedication" : object-node {
                        "label" : "Treatment for AE-Medication",
                        "value" : $aeTreatmentMedication
                    },
                    "eventAeTreatmentProcedure" : object-node {
                        "label" : "Treatment for AE-Procedure/Surgery",
                        "value" : $aeTreatmentProcedure
                    },
                    "eventSubjectDiscontinuedDueToAe" : object-node {
                        "label" : "Subject DC From Study Due to AE",
                        "value" : $subjectDiscontinuedDueToAe
                    },
                    "eventDoseLimitingToxicity" : object-node {
                        "label" : "Dose Limiting Toxicity",
                        "value" : $doseLimitingToxicity
                    },
                    "eventOccurredDuringTimepoint" : object-node {
                        "label" : "AE Occurred During Timepoint",
                        "value" : $occurredDuringTimepoint
                    },
                    "eventIsDeviceInterventionRequired" : object-node {
                        "label" : "If study product was a device, intervention required",
                        "value" : $isDeviceInterventionRequired
                    },
                    "eventNyhaClass" : object-node {
                        "label" : "NYHA Class",
                        "value" : $nyhaClass
                    },
                    "eventPathogen" : object-node {
                        "label" : "Pathogen",
                        "value" : $pathogen
                    },
                    "eventPathogenCode" : object-node {
                        "label" : "Pathogen Code",
                        "value" : $pathogenCode
                    },
                    "eventInitialAeIntensity" : object-node {
                        "label" : "AE Initial Intensity",
                        "value" : $initialAeIntensity
                    },
                    "eventInitialWhoToxicGrade" : object-node {
                        "label" : "AE Initial Intensity WHO Tox Grade",
                        "value" : $initialWhoToxicGrade
                    },
                    "eventExtremeAeIntensity" : object-node {
                        "label" : "AE Extreme Intensity",
                        "value" : $extremeAeIntensity
                    },
                    "eventExtremeWhoToxicGrade" : object-node {
                        "label" : "AE Extreme Intensity WHO Tox Grade",
                        "value" : $extremeWhoToxicGrade
                    }
                },

                (: Begining of Study JSON block :)
                "Study" : object-node {
                    "studyNumber" : object-node {
                        "label" : "Study Number",
                        "value" : $studyName
                    },
                    "studyName" : object-node {
                        "label" : "Study Name",
                        "value" : "TBA"
                    },
                    "studySiteNumber" : object-node {
                        "label" : "Site Number",
                        "value" : $siteNumber
                    },
                    "studySiteName" : object-node {
                        "label" : "Site Name",
                        "value" : $siteName
                    },
                    "studyRandomisationDate" : object-node {
                        "label" : "Randomisation Date",
                        "value" : $randomisationDate
                    },
                    "studySubjectDispositionDate" : object-node {
                        "label" : "Completion Date",
                        "value" : $subjectDispositionDate
                    },
                    "studyReasonSubjectDisposition" : object-node {
                        "label" : "Discontinuation Reason",
                        "value" : $reasonSubjectDisposition
                    },
                    "studyReasonStudyCompletedDiscontinued" : object-node {
                        "label" : "Comp/Disc Reason",
                        "value" : "LACK OF EFFICACY BASED UPON THE PATIENT'S BEST INTEREST"
                    },
                    "studySpecifyStudyCompletedDiscontinued" : object-node {
                        "label" : "Comp/Disc Specify",
                        "value" : "LACK OF EFFICACY BASED UPON THE PATIENT'S BEST INTEREST"
                    }
                },
                (: End Study JSON block :)

                (: Begining of Investigator JSON block :)
                "Investigator" : object-node {
                    "InvestigatorCountry" : object-node {
                        "label" : "Country",
                        "value" : $country
                    },
                    "InvestigatorName" : object-node {
                        "label" : "Investigator name",
                        "value" : $investigatorName
                    }
                },
                (: End of Investigator JSON block :)

                (: Begining of Pregnancy JSON block :)
                "Pregnancy" : if($pregnancyOccuredIn = "") then ('N/A') else(object-node {
					"pregnancyReportDate" : object-node { "label" : "Pregnancy Report Date", "value" : $pregnancyReportDate},
					"pregnancyPrenatalCare" : object-node { "label" : "Prenatal Care", "value" : $prenatalCare},
					"pregnancyWeeksatExposure" : object-node { "label" : "Weeks at exposure ", "value" : $weeksatExposure},
					"pregnancyWeeksatExposureUnit" : object-node { "label" : "Weeks at exposure Unit", "value" : $weeksatExposureUnit},
					"pregnancyReproductiveHistoryPara" : object-node { "label" : "Reproductive History-Para", "value" : $reproductiveHistoryPara},
					"pregnancyFirstDayLastMenstrualPeriod" : object-node { "label" : "First Day Last Menstrual Period", "value" : $firstDayLastMenstrualPeriod},
					"pregnancyAmniocentesisResult" : object-node { "label" : "Amniocentesis Result", "value" : $amniocentesisResult},
					"pregnancyCvsResult" : object-node { "label" : "CVS Result", "value" : $cvsResult},
					"pregnancyEstimatedDateofDelivery" : object-node { "label" : "Estimated Date of Delivery", "value" : $estimatedDateofDelivery},
					"pregnancyReproductiveHistoryGravida" : object-node { "label" : "Reproductive History-Gravida", "value" : $reproductiveHistoryGravida},
					"pregnancyUltrasoundResult" : object-node { "label" : "Ultrasound Result", "value" : $ultrasoundResult},
					"pregnancyTestPerfDurPregAmnio" : object-node { "label" : "Test Perf Dur Preg-Amnio (1,0)", "value" : $testPerfDurPregAmnio},
					"pregnancyTestPerfDurPregCvs" : object-node { "label" : "Test Perf Dur Preg-CVS (1,0)", "value" : $testPerfDurPregCvs},
					"pregnancyTestPerfDurPregNone" : object-node { "label" : "Test Perf Dur Preg-None (1,0)", "value" : $testPerfDurPregNone},
					"pregnancyTestPerfDurPregUltrasd" : object-node { "label" : "Test Perf Dur Preg- Ultrasd (1,0)", "value" : $testPerfDurPregUltrasd},
					"pregnancyTestPerfDurPregUnk" : object-node { "label" : "Test Perf Dur Preg-Unk (1,0)", "value" : $testPerfDurPregUnk},
					"pregnancyOccuredIn" : object-node { "label" : "Pregnancy Occured In", "value" : $pregnancyOccuredIn},
					"pregnancyPartnerSpouseAuthConcent" : object-node { "label" : "Has Partner/spouse authorization/consent been obtained?", "value" : $partnerSpouseAuthConcent},
					"pregnancyNumber" : object-node { "label" : "Pregnancy Number", "value" : $pregnancyNumber},
					"pregnancyNumberofSpontaneousAbortions" : object-node { "label" : "Number of Spontaneous Abortions", "value" : $numberofSpontaneousAbortions},
					"pregnancyNumberofTherapeuticAbortions" : object-node { "label" : "Number of Therapeutic Abortions", "value" : $numberofTherapeuticAbortions},
					"pregnancyHealthCareProfessionalAddress" : object-node { "label" : "Health Care Professional Address", "value" : $healthCareProfessionalAddress},
					"pregnancyHealthCareProfessionaleMail" : object-node { "label" : "Health Care Professional e-Mail", "value" : $healthCareProfessionaleMail},
					"pregnancyHealthCareProfessionalFax" : object-node { "label" : "Health Care Professional FAX", "value" : $healthCareProfessionalFax},
					"pregnancyHealthCareProfessionalName" : object-node { "label" : "Health Care Professional Name", "value" : $healthCareProfessionalName},
					"pregnancyHealthCareProfessionalPhone" : object-node { "label" : "Health Care Professional Phone", "value" : $healthCareProfessionalPhone},
					"pregnancyTpalNumberAbortion" : object-node { "label" : "TPAL Number Abortion", "value" : $tpalNumberAbortion},
					"pregnancyTpalNumberLive" : object-node { "label" : "TPAL Number Live", "value" : $tpalNumberLive},
					"pregnancyTpalNumberPreterm" : object-node { "label" : "TPAL Number Preterm", "value" : $tpalNumberPreterm},
					"pregnancyTpalNumberTerm" : object-node { "label" : "TPAL Number Term", "value" : $tpalNumberTerm},
					"pregnancyWasInterrupted1" : object-node { "label" : "Pregnancy Was Interrupted (Yes,No)", "value" : $pregnancyWasInterrupted1},
					"pregnancyApgarScore1Min1" : object-node { "label" : "Apgar Score-1 Min", "value" : $apgarScore1Min1},
					"pregnancyApgarScore5Min1" : object-node { "label" : "Apgar Score-5 Min", "value" : $apgarScore5Min1},
					"pregnancyDeliveryDate1" : object-node { "label" : "Delivery Date", "value" : $deliveryDate1},
					"pregnancyOutcome1" : object-node { "label" : "Pregnancy Outcome", "value" : $pregnancyOutcome1},
					"pregnancyInfantOutcomeInformation1" : object-node { "label" : "Infant Outcome Information", "value" : $infantOutcomeInformation1},
					"pregnancyInfantSex1" : object-node { "label" : "Infant Sex", "value" : $infantSex1},
					"pregnancyHeadCircumference1" : object-node { "label" : "Head Circumference", "value" : $headCircumference1},
					"pregnancyHeadCircumferenceUnit1" : object-node { "label" : "Head Circumference Unit", "value" : $headCircumferenceUnit1},
					"pregnancyLength1" : object-node { "label" : "Length", "value" : $length1},
					"pregnancyLengthUnit1" : object-node { "label" : "Length Unit", "value" : $lengthUnit1},
					"pregnancyWeight1" : object-node { "label" : "Weight", "value" : $weight1},
					"pregnancyWeightUnit1" : object-node { "label" : "Weight Unit", "value" : $weightUnit1},
					"pregnancyGestationalBirthAge1" : object-node { "label" : "Gestational Birth Age", "value" : $gestationalBirthAge1},
					"pregnancyInterruptedSpecify1" : object-node { "label" : "Pregnancy Interrupted, Specify", "value" : $pregnancyInterruptedSpecify1},
					"pregnancyDateofTermination1" : object-node { "label" : "Date of Termination", "value" : $dateofTermination1},
					"pregnancyWasInterrupted2" : object-node { "label" : "Pregnancy Was Interrupted (Yes,No)", "value" : $pregnancyWasInterrupted2},
					"pregnancyApgarScore1Min2" : object-node { "label" : "Apgar Score - 1 Min", "value" : $apgarScore1Min2},
					"pregnancyApgarScore5Min2" : object-node { "label" : "Apgar Score - 5 Min", "value" : $apgarScore5Min2},
					"pregnancyDeliveryDate2" : object-node { "label" : "Delivery Date", "value" : $deliveryDate2},
					"pregnancyOutcome2" : object-node { "label" : "Pregnancy Outcome", "value" : $pregnancyOutcome2},
					"pregnancyInfantOutcomeInformation2" : object-node { "label" : "Infant Outcome Information", "value" : $infantOutcomeInformation2},
					"pregnancyInfantSex2" : object-node { "label" : "Infant Sex", "value" : $infantSex2},
					"pregnancyHeadCircumference2" : object-node { "label" : "Head Circumference", "value" : $headCircumference2},
					"pregnancyHeadCircumferenceUnit2" : object-node { "label" : "Head Circumference Unit", "value" : $headCircumferenceUnit2},
					"pregnancyLength2" : object-node { "label" : "Length", "value" : $length2},
					"pregnancyLengthUnit2" : object-node { "label" : "Length Unit", "value" : $lengthUnit2},
					"pregnancyWeight2" : object-node { "label" : "Weight", "value" : $weight2},
					"pregnancyWeightUnit2" : object-node { "label" : "Weight Unit", "value" : $weightUnit2},
					"pregnancyGestationalBirthAge2" : object-node { "label" : "Gestational Birth Age", "value" : $gestationalBirthAge2},
					"pregnancyInterruptedSpecify2" : object-node { "label" : "Pregnancy Interrupted-Specify", "value" : $pregnancyInterruptedSpecify2},
					"pregnancyDateofTermination2" : object-node { "label" : "Date of Termination", "value" : $dateofTermination2},
					"pregnancyNotApplicableBabyNumber2" : object-node { "label" : "Not Applicable-Baby Number 2", "value" : $notApplicableBabyNumber2}
                }),
                (: End of Pregnancy JSON block :)

                "Drug" :
                csae-json-drug:create-elements($drugMap),
                "Medical Condition" :
                csae-json-medhistory:create-elements($medHistoryMap),
                "ConMed" :
                csae-json-conmed:create-elements($conMedMap),


                (: Begining of Patient JSON block :)
                "Patient": csae-json-patient:get-patient($onsetDate, 
														 $StudyId, 
														 $StudyEnvironment, 
														 $SubjectNumber, 
														 $studyName),
                (: Begining of Patient JSON block :)

                (: Begining of Additional Information JSON block :)
                "Additional Information" : "N/A",
                (: Begining of Additional Information JSON block :)

                "Narrative" :
                object-node {
                "narrativeRelevantDiagnosticTests" :
                object-node {
                "label" : "Relevant Diagnostic Tests Performed",
                "value" : $relevantDiagnosticTests
                },
                "narrativeAdditionalDetails1" :
                object-node {
                "label" : "Additional Case Details",
                "value" : $additionalDetails1
                },
                "narrativeAdditionalDetails2" :
                object-node {
                "label" : "Additional Case Details",
                "value" : $additionalDetails2
                },
                "narrativeAdditionalDetails3" :
                object-node {
                "label" : "Additional Case Details",
                "value" : $additionalDetails3
                },
                "narrativeAdditionalDetails4" :
                object-node {
                "label" : "Additional Case Details",
                "value" : $additionalDetails4
                }
                }

                }
                }
                }

			let $previousReport := csae:get-latest-report($StudyId, $SubjectNumber, $studyEnvironment, $AeSeq)									  
            let $previousStatus := $previousReport/content/Report/Event/eventAeUpgradeDowngrade/value
            let $reportUri := concat(("/saegeneration/saereports/DCH-AE-"), $studyName, ("-"),  $studyEnvironment, ("-"),  $subjectName, ("-"), $aeNumber, ("-"), $version)
            let $reportCollection := "saegeneration/saereports/reportsForSending"
            let $config := fn:doc("/saegeneration/lib/followUpConfigDocument.json")
            (:if there is no previous version, then save the generated one:)
            return 
                if (fn:empty(csae:get-latest-report($StudyId, $SubjectNumber, $studyEnvironment, $AeSeq)))
                then (xdmp:document-insert($reportUri, $reportDocument, xdmp:default-permissions(), $reportCollection))
                else (
                    (: See if report has been reactivated :)         
                    if ($reportable = "Y" and $previousStatus = "INVALIDATED")
                    then (
                        (: Mark as reactivated and save followup report :)
                        xdmp:node-replace($reportDocument/content/Report/Event/eventAeUpgradeDowngrade/value, text{"REACTIVATED"}),
                        xdmp:document-insert($reportUri, $reportDocument, xdmp:default-permissions(), $reportCollection),
                        xdmp:node-replace($previousReport/headers/isCurrent, boolean-node {fn:false()})                   
                    )
                    else(
                        (: if there is a previous version start comparison based on a config file :)
                        let $comparison :=
                            for $i in $config/content/text()
                            return (xdmp:value("$reportDocument/content"||$i||"/text()[2]") eq xdmp:value("$previousReport/content"||$i||"/text()[2]"))
                        (: if there is a comparison condition that does not match then save the generated report :)
                        return if (fn:matches((<doc>{$comparison}</doc>),"false"))
                             then (
                                  xdmp:document-insert($reportUri, $reportDocument, xdmp:default-permissions(), $reportCollection),
                                  xdmp:node-replace($previousReport/headers/isCurrent, boolean-node {fn:false()})
                             )
                            (: if all simgle fields are queal start comparision for multi-fleds blocks :)
                            else (
                                let $multi-comparison := fn:true()
                                (: use $_ temporary variable :)
                                let $_ :=
                                    for $i in $config/multi-content-count/text()
                                        return
                                        (: first check if count of object nodes for every multi-field block is equal btw alredy sent and current report :)
                                        if (fn:count(xdmp:value("$reportDocument/content/Report/"||$i)) ne fn:count(xdmp:value("$previousReport/content/Report/"||$i)))
                                        (: if not equal then set $multi-comparison variable to false :)
                                        then (xdmp:set($multi-comparison, fn:false()))
                                        else ()

                                let $_ :=
                                    if ($multi-comparison)
                                    then (
                                        for $i in $reportDocument/content/Report/General
                                        let $j:= $previousReport/content/Report/General[(generalReportId/text()[2]) = ($i/generalReportId/text()[2])]
                                        let $curr := $i/../Medical-Condition
                                        let $prev := $j/../Medical-Condition
                                            for $iter in (1 to 5)
                                                for $u in $prev/object-node()[$iter]/text()[2]
                                                where (fn:not($u eq $curr/object-node()[$iter]/text()[2]))
                                                return
                                                    if (fn:not($u eq $curr/object-node()[$iter]/text()[2]))
                                                    then (xdmp:set($multi-comparison, fn:false()))
                                                    else ()
                                    )
                                    else ()
                                        return
                                            if (fn:not($multi-comparison))
                                            then (
                                                  xdmp:document-insert($reportUri, $reportDocument, xdmp:default-permissions(), $reportCollection),
                                                  xdmp:node-replace($previousReport/headers/isCurrent, boolean-node {fn:false()})
                                            )
                                            else ()
                            )
                            (: end of comparision for multi-fleds blocks :)
                )
            )

    )
};