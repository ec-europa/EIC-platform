xquery version "1.0";
(: ------------------------------------------------------------------
   POLL - EIC Poll Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   Shared utilities

   July 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace poll = "http://oppidoc.com/ns/poll";

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "services.xqm";

(: ======================================================================
   Converts edition-oriented tag names (i.e. Likert_XXX tag) towards 
   storage-oriented tag names (i.e. RatingScaleRef For="XXX")

   Benefit of using edition-oriented tag names is to simplify questionnaires 
   reengineering to change question order or add or remove questions 
   w/o requiring to migrate database content
   ======================================================================
:)
declare function poll:genPollDataForWriting( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element() return
        let $chunk := tokenize(local-name($node), '_')[. ne '']
        return
          if ($chunk[1] = 'Likert') then
            if ($chunk[3]) then
              element { $chunk[2] } { attribute For { $chunk[last()] }, $node/text() }
            else
              element RatingScaleRef { attribute For { $chunk[last()] }, $node/text() }
          else if ($chunk[1] = 'Comment') then
              element Comment { attribute For { $chunk[last()] }, $node/(text() | *) }
          else
            element { node-name($node) }
              { poll:genPollDataForWriting($node/(attribute()|node())) }
      default return $node
};

(: ======================================================================
   Reverse of local:encodePollData
   ======================================================================
:)
declare function poll:genPollDataForEditing ( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element() return
        if ($node/@For) then
          let $suffix := string($node/@For)
          return
            if (local-name($node) eq 'Comment') then
              element { concat(local-name($node), '_', $suffix) } { $node/(text() | *) }
            else (: Assuming entry node is amongst (RatingScaleRef, SupportScaleRef, CommunicationAdviceRef) :)
              element { concat('Likert_', local-name($node), '_', $suffix) }
                {
                $node/text()
                }
        else
          element { local-name($node) }
            { poll:genPollDataForEditing($node/(attribute()|node())) }
      default return $node
};

(: ======================================================================
   Returns the order in the command or raises an error
   The Order Id MUST be the command target
   ======================================================================
:)
declare function poll:get-order() as element()? {
  let $cmd := request:get-attribute('oppidum.command')
  let $order-id := $cmd/resource/@name
  let $order := fn:collection($globals:forms-uri)//Order[Id = $order-id]
  return
    if ($order) then
      $order
    else
      oppidum:throw-error('ORDER-NOT-FOUND', $order-id)
};

(: ======================================================================
   Returns true if all the Bindings in the questionnaire specification
   hold true, false otherwise
   Works with Flat questionnaire model where answers are tags at 1st level
   Currently limited to ONE Recommended binding
   ======================================================================
:)
declare function poll:check-answers( $name as xs:string, $answers as element() ) as xs:boolean {
  let $spec := fn:collection($globals:questionnaires-uri)//Poll[Id eq $name]
  return
    if ($spec) then
      count(
        for $t in tokenize($spec/Bindings/Recommended/@Keys, ' ')[. ne '']
        let $key := normalize-space($t)
        return
          if ($answers/*[ends-with(local-name(.),$key)]/text()) then
            ()
          else
            1
      ) = 0
    else
      true()
};

(: ======================================================================
   Tests the user has at least answered to one question
   TODO: store XPath condition into Questionnaire spec and evaluate it
   when available to handle more complex logics ?
   ======================================================================
:)
declare function poll:check-no-answer( $name as xs:string, $answers as element() ) as xs:boolean {
  count($answers//*[. ne '']) eq 0
};

(: ======================================================================
   Wrapper to POST XML payload to questionnaire's Hook
   ======================================================================
:)
declare function poll:post-to-hook-for( $questionnaire as xs:string, $payload as element() ) as element()? {
  let $spec-uri := concat($globals:questionnaires-uri, '/', $questionnaire, '.xml')
  return
    if (not(doc-available($spec-uri))) then
      oppidum:throw-error('QUESTIONNAIRE-NOT-FOUND', $questionnaire)
    else if (fn:doc($spec-uri)//Hook) then
      let $hook := fn:doc($spec-uri)//Hook
      let $address := string($hook)
      return
        services:post-to-address($address, $payload, ("200", "201", "202"), string($hook/@Name))
    else (: no hook :)
      ()
};

