xquery version "1.0";
(: Path written to be executed from Java admin client :)
(: replace webapp/ by ../ to run from exist sandbox :)
(: add prefix ../../../ for running by tunnelling from local instance of eXist :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace mail = "http://exist-db.org/xquery/mail";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare function local:report-exception( $to as xs:string ) as xs:string
{
 let $err :=  concat("Failed to send email message : ", $util:exception-message)
 return
   $err
};


(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('ccmatch-public', 'ccmatch.mail.relay', $submitted)
return
  if (empty($errors)) then
    let $mail := services:unmarshall($submitted)
    return
      let $to-send :=
        <mail>
          <from>{ $mail/from/text() }</from>
          <reply-to>{ $mail/reply-to/text() }</reply-to>
          {
          for $to in $mail/to
          return <to>{ $to/text() }</to>
          }
          {
          for $cc in $mail/cc
          return <cc>{ $cc/text() }</cc>
          }
          <subject>{ $mail/subject/text() }</subject>
          <message>{ $mail/message/node() }</message>
          {
          for $a in $mail/attachment
          return element attachment { $a/@*, $a/node() }
          }
        </mail>
      return
        let $server := "localhost"
        return 
          let $res := util:catch('*', mail:send-email($to-send , $server, ()), local:report-exception("dummy"))
          return 
            if ($res eq true()) then 
              <Done>{ $res }</Done>
            else if ($res castable as xs:string) then
              <Exception>{ $res }</Exception>
            else
              <Unknown>{ $res }</Unknown>
  else
    $errors