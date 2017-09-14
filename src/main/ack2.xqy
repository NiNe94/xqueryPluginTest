xquery version "1.0-ml";
import module namespace rest="http://marklogic.com/appservices/rest" at "/MarkLogic/appservices/utils/rest.xqy";
import module namespace requests =  "http://marklogic.com/appservices/requests" at "/saegeneration/lib/requests.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

(: Process requests to be handled by this endpoint module. :)

declare function local:send-notification (  $status as xs:string, $failed-warning-ack as node() ) as xs:string
  
{    
	(: this is to send an email message to the support team - the notification function is awaited :)
	let $sent:= "OK" (: dummy value for debug:)
	return $sent
};

declare function local:throw-exception-with-notification (  $message as xs:string , $invalidNode as node())  as empty-sequence()
  (: $content as node() - when notification function is ready this variable will contain received json to be sent as an attachment :)
{    
	(:requirement to be precised: should we store the acknowledgement in a dedicated collection or attach it to the report header doc in db or just send it to the support as an attachment :)
	(: storing document  xdmp:document-insert($doc_name, $invalidNode) :)
	(: function local:send-notification to be called here to send notification awaited for completion :)
	(: let $send := local:send-notification($message , $invalidNode) :)
	(: xdmp:log($message),
	xdmp:log($invalidNode), :)
	fn:error(xs:QName("ERROR"), $message) 
};

declare function local:get-valid-trxid($ackDocument as node()) as xs:string
{
	let $valid-trxid := 
						if (fn:empty($ackDocument/acknowledgement/transactionId ) )
							then local:throw-exception-with-notification("missing aeroTransactionId",$ackDocument ) 
							else $ackDocument/acknowledgement/transactionId
	return (xdmp:log($valid-trxid),$valid-trxid)
};

declare function local:get-valid-status($ackDocument as node()) as xs:string
{
	let $status :=$ackDocument/acknowledgement/status
(:	let $notification:=
					if ($status="FAILED" or $status="WARNING")  
						then local:send-notification ($status, $ackDocument)
						else () - to be tested when local:send-notification is completed, this is to inform the support that the status is either FAILED or WARNING
:)
		return if ($status="SUCCESS" or $status="FAILED" or $status="WARNING") then $status else local:throw-exception-with-notification("unknown status",$ackDocument) 
};

declare function local:get-valid-node($ackDocument as node()) as node()*
{
	let $trxid:=local:get-valid-trxid($ackDocument)
	let $valid-node := cts:search(collection("saegeneration/saereports/reportsSent"),cts:json-property-value-query("transactionId",$trxid),"score-zero", 0.0)
	(:  other validations to be done here if existis if no more than 1 etc 
	if (fn:count ($valid-node<>1))	then 
		then cts:search(collection("reportsSentCollection"),cts:json-property-value-query("transactionId",local:get-valid-trxid($ackDocument))/headers
		else  local:throw-exception-with-notification("there is no single report with aeroTransactionId provided in the acknowledgement",$ackDocument)	
	:)
	return $valid-node
};

(: main body :)


let $request := $requests:options/rest:request
                  [@endpoint = "/saegeneration/lib/ack2.xqy"][1] 

let $type    := xdmp:get-request-header('Content-Type')

let $format :=
					if ($type = 'application/json' or ends-with($type, '+json'))
						then  "json"
						else local:throw-exception-with-notification("not a json format", <msg>not a json format</msg>)
(: Content-Type: json validation :)	

let $body := xdmp:get-request-body($format)/node()
(: the content of the request body extracted to $body object-node in json only :)

let $target-node :=local:get-valid-node($body)
let $target-uri :=fn:document-uri($target-node)
let $status:=local:get-valid-status($body)
let $set-status := xdmp:node-replace($target-node/headers/reportStatus, text{$status})
let $target-collection := if ($status eq "FAILED") then (xdmp:document-remove-collections($target-uri, "saegeneration/saereports/reportsSent"),
	xdmp:document-add-collections($target-uri, "saegeneration/saereports/reportsFailed"),xdmp:log(fn:concat("[SAE] document moved to reportsFailedCollection:",$target-uri)) )
	else (xdmp:log("[SAE] document PROCESSED with SUCCESS by AERO")) 
	
return (xdmp:log($body),xdmp:node-insert-child($target-node/headers, object-node {"ack2": $body }/ack2))

(: main body end:)
(:
it is based on the assumption that we insert acknowledgement into the report header
	
in case there is no need to return ERROR 500 to aero when we identify a problem then main body  should be wrapped into
try {main body here} catch (e$) { local:throw-exception-with-notification("error",e$)}	and fn:error removed from the function
:)