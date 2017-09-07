xquery version "1.0-ml";

module namespace reporting = "http://roche.com/data-capture-hub/saegeneration/lib/reporting";

declare namespace http="xdmp:http";

declare variable $config := fn:doc("/saereports/config/AeroConfig.json");
(: Name of an attribute holding aero transaction id :)
declare variable  $aeroTransactionIdAttribute  := $config/aeroTransactionIdAttribute;
(: Notification to support will be sent when count of first level failed acknowledgements reaches this treshold :)
declare variable  $firstLevelFailureNotificationTreshold := $config/firstLevelFailureNotificationTreshold/number();
(: Definiton of a date-time format for AE Reporting purposes :)
declare variable  $aeReportingDateTimeFormat  := $config/aeReportingDateTimeFormat;
declare variable $aeroUrl :=$config/aeroURL;
declare variable $apiKey :=$config/apiKey;
declare variable $timeout :=$config/timeout/number();
(:~
 :  This function will make a POST request including the document content to the remote endpoint.
 :
 :  @param $documentUrl         - URL of the document to be published
 :  @param $aeroUrl             - URL of an external system to which the report will be sent
 :  @param $apiKey              - API key to be used in the header of the post request
 :  @param $timeout             - Timeout for the response from external system
 :
 :)
declare function reporting:post-ae-report(
    $documentUrl as xs:string
) as xs:double*
{
    try {
		let $content := fn:doc($documentUrl)/content
        let $postTimestamp := fn:adjust-dateTime-to-timezone(current-dateTime(), xs:dayTimeDuration('PT0H'))
        let $response := xdmp:http-post($aeroUrl,
            <options xmlns="xdmp:http">
                <headers>
                    <content-type>application/json</content-type>
                    <apiKey>{$apiKey}</apiKey>
                </headers>
            <timeout>{$timeout}</timeout>
            </options>,
        $content)
        let $responseCode := $response[1]//http:code/number()
		let $transactionId := $response[2]/xdmp:value($aeroTransactionIdAttribute)
        let $status := $response[2]/status

      let $_:= if ($responseCode=202 ) then reporting:handle-successful-post($documentUrl, $response[2]/xdmp:value($aeroTransactionIdAttribute), $postTimestamp)
else if ($responseCode=400 ) then  reporting:handle-failed-post-400 ($documentUrl, $postTimestamp)
else  reporting:handle-failed-post($documentUrl, $postTimestamp)
return $responseCode
    } catch ($exception) {
        xdmp:log(fn:concat($documentUrl, " - Exception while reporting to AERO")),
        xdmp:log($exception)
    }
};

declare private function reporting:handle-successful-post(
    $documentUrl as xs:string,
    $aeroTransactionId as xs:string,
    $postTimestamp as xs:dateTime?
)
{
    reporting:update-header-attribute($documentUrl, "firstLevelAckReceivedOn", reporting:get-utc-date-time-string(current-dateTime())),
    reporting:update-header-attribute($documentUrl, "reportSentOn", reporting:get-utc-date-time-string($postTimestamp)),
    reporting:update-header-attribute($documentUrl, "reportStatus", "PROCESSING"),
    reporting:update-header-attribute($documentUrl, $aeroTransactionIdAttribute, $aeroTransactionId),
    xdmp:document-remove-collections($documentUrl, "saegeneration/saereports/reportsForSending"),
	xdmp:document-add-collections($documentUrl, "saegeneration/saereports/reportsSent"),
    xdmp:log(fn:concat($documentUrl, " - successfully posted to AERO."))
};

declare private function reporting:handle-failed-post(
    $documentUrl as xs:string,
    $postTimestamp as xs:dateTime?
)
{
    reporting:update-header-attribute($documentUrl, "firstLevelAckReceivedOn", reporting:get-utc-date-time-string(current-dateTime())),
    reporting:update-header-attribute($documentUrl, "reportSentOn", reporting:get-utc-date-time-string($postTimestamp)),

    let $firstLevelFailureCount := fn:doc($documentUrl)/headers/firstLevelTrialCount
    return if (fn:empty($firstLevelFailureCount))
    then (
        let $failureNode := object-node {"firstLevelTrialCount" : 1}
        return xdmp:node-insert-child(fn:doc($documentUrl)/headers, $failureNode/firstLevelTrialCount)
    )
    else (
        xdmp:node-replace(fn:doc($documentUrl)/headers/firstLevelTrialCount, object-node {"firstLevelTrialCount" : $firstLevelFailureCount/number() + 1}/firstLevelTrialCount),
        if ($firstLevelFailureCount/number() lt $firstLevelFailureNotificationTreshold)
        then xdmp:log(fn:concat($documentUrl, " - 1st level ack failure, notification will be sent")) (: TO DO - notification to be called here:)
        else xdmp:log(fn:concat($documentUrl, " - 1st level ack failure, notification will not be sent"))
    )

};

declare private function reporting:handle-failed-post-400(
    $documentUrl as xs:string,
    $postTimestamp as xs:dateTime?
)
{
    reporting:update-header-attribute($documentUrl, "firstLevelAckReceivedOn", reporting:get-utc-date-time-string(current-dateTime())),
    reporting:update-header-attribute($documentUrl, "reportSentOn", reporting:get-utc-date-time-string($postTimestamp)),
   	xdmp:document-remove-collections($documentUrl, "saegeneration/saereports/reportsForSending"),
	xdmp:document-add-collections($documentUrl, "saegeneration/saereports/reportsFailed"),
	xdmp:node-replace(fn:doc($documentUrl)/headers/reportStatus/text(), text {"FAILED"})
 };


declare private function reporting:update-header-attribute(
    $documentUrl as xs:string,
    $attributeName as xs:string,
    $attributeValue as xs:string
)
{
    let $header := fn:doc($documentUrl)/headers
    let $attributeNode := object-node {xdmp:quote($attributeName) : $attributeValue}

    return try{
        xdmp:node-insert-child($header, $attributeNode/xdmp:value($attributeName))
    } catch ($exception) {
        xdmp:node-replace($header/xdmp:value($attributeName), $attributeNode/xdmp:value($attributeName))
    }
};

declare private function reporting:get-utc-date-time-string($timestamp as xs:dateTime) as xs:string*
{
    let $adjustedDateTime := fn:adjust-dateTime-to-timezone($timestamp, xs:dayTimeDuration('PT0H'))
    return fn:format-dateTime($adjustedDateTime, $aeReportingDateTimeFormat)
};