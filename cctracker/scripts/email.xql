xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Frédéric Dumonceaux <fred.dumonceaux@gmail.com>

   Contributions: Stéphane Sire <s.sire@oppidoc.fr>

   Utility to send "unplugged" e-mail archived in /db/debug/debug.xml

   Path in import statements is written to be executed 
   by a database instance launched by the wrapper using :

   ./bin/client.sh -u admin -P XXXX -ouri=xmldb:exist://localhost:YYYY/exist/xmlrpc -F email.xql

   Adjust the path to run it from a Java admin client or from eXist-DB sandbox

   May 2016 - European Union Public Licence EUPL
   -------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace mail = "http://exist-db.org/xquery/mail";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../lib/media.xqm";

declare function local:report-exception() as xs:boolean
{
 let $err :=  concat("Failed to send email message : ", $util:exception-message)
 return
   false()
};

let $server := fn:doc($globals:settings-uri)/Settings/SMTPServer/text()
return
  <Batch Server="{ $server }">
    {
    for $mail in fn:doc('/db/debug/debug.xml')/Debug/mail[@status = 'unplugged']
    return
      <ToSend>
        {
          attribute Status { $mail/@status },
          attribute Date { $mail/@date },
          (: 
            NOTE that it does not work (ProxyNode exception) if initialized with
            let $to-send := <mail>{ $mail/* }</mail>
          :)
          let $to-send := <mail>
                         <from>{ string($mail/from) }</from>
                         <to>{ string($mail/to) }</to>
                         <reply-to>{ string($mail/reply-to) }</reply-to>
                         { 
                         for $c in $mail/cc
                         return <cc>{ string($c) }</cc>
                         }
                         <subject>{ string($mail/subject) }</subject>
                         <message><text>{ string($mail/message/text) }</text></message>
                       </mail>
          return
            let $sent :=
              if (util:catch('*', mail:send-email($to-send, $server, ()), local:report-exception())) then
                true()
              else
                false()
            return
                if ($sent) then
                (
                  update delete $mail/@status,
                  update value $mail/@date with current-dateTime(),
                  <Done To="{$to-send/to/text()}">{ $to-send }</Done>
                )
                else
                  <Exception To="{$to-send/to/text()}">{ $to-send }</Exception>
        }
      </ToSend>,
    element Count { count(fn:doc('/db/debug/debug.xml')/Debug/mail[@status = 'unplugged']) }
    }
  </Batch>
