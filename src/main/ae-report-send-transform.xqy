xquery version "1.0-ml";

import module namespace reporting = "http://roche.com/data-capture-hub/saegeneration/lib/reporting" at "/saegeneration/lib/reporting.xqy";
import module namespace logtool = "http://roche.com/data-capture-hub/saegeneration/lib/logtool" at "/saegeneration/lib/logtool.xqy";

declare variable $URI as xs:string external;
logtool:log(fn:concat("[INFO] sending URI:",$URI)),
reporting:post-ae-report($URI)