xquery version "1.0-ml";

let $URIS:=cts:uris((),(), cts:and-query((
    cts:json-property-value-query("reportStatus","READY"),
    cts:collection-query("saegeneration/saereports/reportsForSending"))
))
return (fn:count($URIS),$URIS)