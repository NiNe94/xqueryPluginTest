xquery version "1.0-ml";

module namespace csae-json-medhistory = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/medhistory";

import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

(: This function will generate a map with all of the Subjects, and the corresponding medical condition and the med condition items for a given subject :)
declare function csae-json-medhistory:get-map($StudyId, $StudyEnvironment, $SubjectNumber)
{
    let $map := map:map()
    let $medHistory := op:from-view("CSAE", "MedicalHistory")
    let $results :=
        $medHistory
        => op:where(
				op:and(
                    op:eq(op:view-col("MedicalHistory", "StudyId"), $StudyId),
                    op:and(
                        op:eq(op:view-col("MedicalHistory", "StudyEnvironment"), $StudyEnvironment),
                        op:eq(op:view-col("MedicalHistory", "SubjectNumber"), $SubjectNumber)
                    )
                )					
        )		
        => op:select(("SubjectName", "MedicalCondition", "MedicalHistoryType", "StatusOfDisease", "StartDate", "EndDate"))
        => op:result()
    let $doc := <doc>{$results}</doc>
    let $_ :=
        for $result in $doc/json:object
        let $medicalCondition := $result/json:entry[@key eq "CSAE.MedicalHistory.MedicalCondition"]/json:value/string()
        let $medicalHistoryType := $result/json:entry[@key eq "CSAE.MedicalHistory.MedicalHistoryType"]/json:value/string()
        let $statusOfDisease := $result/json:entry[@key eq "CSAE.MedicalHistory.StatusOfDisease"]/json:value/string()
        let $startDate := $result/json:entry[@key eq "CSAE.MedicalHistory.StartDate"]/json:value/string()
        let $endDate := $result/json:entry[@key eq "CSAE.MedicalHistory.EndDate"]/json:value/string()
        return map:put($map, $medicalCondition, ($medicalHistoryType, $statusOfDisease, $startDate, $endDate))


    return $map
};


(: This will return the JSON array for the med history :)
declare function csae-json-medhistory:create-elements(
        $map as map:map
)
{
    array-node {
        for $value-key in map:keys($map)
        let $values := map:get($map, $value-key)
        return
            object-node {
                "medicalCondition" : object-node {
                    "label" : "Medical Condition",
                    "value" : $value-key
                },
                "medicalConditionHistoryType" : object-node {
                    "label" : "Medical History Type",
                    "value" : $values[1]
                },
                "medicalConditionStatus" : object-node {
                    "label" : "Status of Disease",
                    "value" : $values[2]
                },
                "medicalConditionStartDate" : object-node {
                    "label" : "Start Date",
                    "value" : $values[3]
                },
                "medicalConditionEndDate" : object-node {
                    "label" : "End Date",
                    "value" : $values[4]
                },
                "medicalConditionPreDefined" : object-node {
                    "label" : "Medical Condition Pre-defined",
                    "value" : "Y"
                },
                "medicalConditionHistoryOfCondition" : object-node {
                    "label" : "Subject Has History of Condition",
                    "value" : "Yes"
                }
            }
    }
};
