xquery version "1.0-ml";

module namespace csae-json-drug = "http://roche.com/ae-reporting/saegeneration/lib/csae-json/drug";

import module namespace op = "http://marklogic.com/optic" at "/MarkLogic/optic.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

(: This function will generate a map with all of the Subjects, and the corresponding start dates and the drug for a given subject :)
declare function csae-json-drug:get-map($StudyId, $StudyEnvironment, $SubjectNumber)
{
    let $map := map:map()
    let $drugAdministration := op:from-view("CSAE", "DrugAdministration")
    let $results :=
        $drugAdministration
        => op:where(
				op:and(
                    op:eq(op:view-col("DrugAdministration", "StudyId"), $StudyId),
                    op:and(
                        op:eq(op:view-col("DrugAdministration", "StudyEnvironment"), $StudyEnvironment),
                        op:eq(op:view-col("DrugAdministration", "SubjectNumber"), $SubjectNumber)
                    )
                )					
        )
        => op:select(("DrugName", "DateAdministered"))
        => op:result()
    let $doc := <doc>{$results}</doc>
    let $_ := for $result in $doc/json:object
				let $dateAdministered := $result/json:entry[@key eq "CSAE.DrugAdministration.DateAdministered"]/json:value/string()
				let $drugName := $result/json:entry[@key eq "CSAE.DrugAdministration.DrugName"]/json:value/string()
				return map:put($map, $dateAdministered, $drugName)

	return $map
};

(: This will return the JSON array for the drugs :)
declare function csae-json-drug:create-elements(
        $map as map:map
)
{
    array-node {
        for $key in map:keys($map)
			return	
				object-node {
				"drugName" : object-node {
				"label" : "Medication Name - Raw Term",
				"value" : map:get($map, $key)
				},
				"drugStartDate" : object-node {
				"label" : "Medication Start Date",
				"value" : $key
				}
				}
    }
};
