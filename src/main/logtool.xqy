xquery version "1.0-ml";

module namespace logtool = "http://roche.com/data-capture-hub/saegeneration/lib/logtool";

declare function logtool:log-attachment (  $msg as xs:string, $attachment as node() ) as empty-sequence()
{    
logtool:log($msg),
xdmp:log($attachment)
 
 };
  
declare function logtool:log ($msg as xs:string ) as empty-sequence()
{    

let $message := fn:concat("[SAE] ", $msg)
return xdmp:log($message)

};

