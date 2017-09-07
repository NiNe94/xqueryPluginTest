xquery version "1.0-ml";
module namespace     requests="http://marklogic.com/appservices/requests";
import module namespace rest = "http://marklogic.com/appservices/rest"
    at "/MarkLogic/appservices/utils/rest.xqy";
declare variable $requests:options as element(rest:options)
:=
  <options xmlns="http://marklogic.com/appservices/rest">
   <request uri="^/ack2(.+)$" endpoint="saegeneration/lib/ack2.xqy">
   <http method="POST"/>
</request>
  </options>;