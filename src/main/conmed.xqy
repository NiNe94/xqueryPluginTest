xquery version "1.0-ml";

module namespace csae-json-conmed = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/conmed";

import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

(: This function will generate a map with all of the Subjects, and the corresponding conmed and the conmed items for a given subject :)
declare function csae-json-conmed:get-map($StudyId, $StudyEnvironment, $SubjectNumber)
{
    let $map := map:map()
    let $conMed := op:from-view("CSAE", "ConcomitantMedications")
    let $results :=
        $conMed
        => op:where(
				op:and(
                    op:eq(op:view-col("ConcomitantMedications", "StudyId"), $StudyId),
                    op:and(
                        op:eq(op:view-col("ConcomitantMedications", "StudyEnvironment"), $StudyEnvironment),
                        op:eq(op:view-col("ConcomitantMedications", "SubjectNumber"), $SubjectNumber)
                    )
                )					
        )		
        => op:select(("SubjectName", "ConmedNumber", "ConmedName", "IndicationTerm", "RouteOfAdmin", "StartDate", "EndDate", "Ongoing", "ForProphylaxis", "Dose", "DoseForm", "DoseUnit", "Frequency", "IndicationOthers", "ParentStudyConMedNumber"))
        => op:result()
    let $doc := <doc>{$results}</doc>
    let $_ :=
        for $result in $doc/json:object
        let $subjectName := $result/json:entry[@key eq "CSAE.ConcomitantMedications.SubjectName"]/json:value/string()
        let $conmedNumber := $result/json:entry[@key eq "CSAE.ConcomitantMedications.ConmedNumber"]/json:value/string()
        let $conmedName := $result/json:entry[@key eq "CSAE.ConcomitantMedications.ConmedName"]/json:value/string()
        let $indicationTerm := $result/json:entry[@key eq "CSAE.ConcomitantMedications.IndicationTerm"]/json:value/string()
        let $routeOfAdmin := $result/json:entry[@key eq "CSAE.ConcomitantMedications.RouteOfAdmin"]/json:value/string()
        let $startDate := $result/json:entry[@key eq "CSAE.ConcomitantMedications.StartDate"]/json:value/string()
        let $endDate := $result/json:entry[@key eq "CSAE.ConcomitantMedications.EndDate"]/json:value/string()
        let $ongoing := $result/json:entry[@key eq "CSAE.ConcomitantMedications.Ongoing"]/json:value/string()
        let $forProphylaxis := $result/json:entry[@key eq "CSAE.ConcomitantMedications.ForProphylaxis"]/json:value/string()
        let $Dose := $result/json:entry[@key eq "CSAE.ConcomitantMedications.Dose"]/json:value/string()		
        let $DoseForm := $result/json:entry[@key eq "CSAE.ConcomitantMedications.DoseForm"]/json:value/string()
		let $DoseUnit := $result/json:entry[@key eq "CSAE.ConcomitantMedications.DoseUnit"]/json:value/string()
        let $Frequency := $result/json:entry[@key eq "CSAE.ConcomitantMedications.Frequency"]/json:value/string()
		let $IndicationOthers := $result/json:entry[@key eq "CSAE.ConcomitantMedications.IndicationOthers"]/json:value/string()
        let $ParentStudyConMedNumber := $result/json:entry[@key eq "CSAE.ConcomitantMedications.ParentStudyConMedNumber"]/json:value/string()		
        return
            map:put($map, $conmedNumber, ($conmedName, $indicationTerm, $routeOfAdmin, $startDate, $endDate, $ongoing, $forProphylaxis, $Dose, $DoseForm, $DoseUnit, $Frequency, $IndicationOthers, $ParentStudyConMedNumber))

    return $map
};


(: This will return the JSON array for the med history :)
declare function csae-json-conmed:create-elements(
        $map as map:map
)
{
    array-node {
        for $value-key in map:keys($map)
        let $values := map:get($map, $value-key)
        return
            object-node {
            "conmedNumber" :
            object-node {
            "label" : "Con Med Number",
            "value" : $value-key
            },
            "conmedName" :
            object-node {
            "label" : "Medication Name - Raw Term",
            "value" : $values[1]
            },
            "conmedRouteOfAdmin" :
            object-node {
            "label" : "Medication Route",
            "value" : $values[3]
            },
            "conmedStartDate" :
            object-node {
            "label" : "Medication Start Date",
            "value" : $values[4]
            },
            "conmedEndDate" :
            object-node {
            "label" : "Medication Stop Date",
            "value" : $values[5]
            },
            "conmedOngoing" :
            object-node {
            "label" : "Medication is Ongoing",
            "value" : $values[6]
            },
            "conmedIndicationTerm" :
            object-node {
            "label" : "Medication Indication",
            "value" : $values[2]
            },
            "conmedForProphylaxis" :
            object-node {
            "label" : "Given for Prophylaxis",
            "value" : $values[7]
            },			
            "conmedDose" :
            object-node {
            "label" : "Medication Dose",
            "value" : $values[8]
            },			
            "conmedDoseForm" :
            object-node {
            "label" : "Dose Form",
            "value" : $values[9]
            },			
            "conmedDoseUnit" :
            object-node {
            "label" : "Medication Dose Unit",
            "value" : $values[10]
            },
            "conmedFrequency" :
            object-node {
            "label" : "Medication Frequency",
            "value" : $values[11]
            },
            "conmedIndicationOthers" :
            object-node {
            "label" : "Indication, Other Specify",
            "value" : $values[12]
            },
            "conmedParentStudyConMedNumber" :
            object-node {
            "label" : "Parent Con Med Number",
            "value" : $values[13]
            }			
            }
    }
};
