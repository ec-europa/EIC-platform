xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Test File

   July 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../lib/services.xqm";
import module namespace evaluation = "http://oppidoc.com/ns/cctracker/evaluation" at "../modules/activities/evaluation.xqm";

(: ======================================================================
   Loopback test to check Poll service is correctly configured
   ======================================================================
:)
declare function local:test1 ( ) {
  let $sample := 
      <Data>
        <Foo>Hello World</Foo>
      </Data>
  return
    services:post-to-service('poll', 'poll.loopback', $sample, ("200", "201"))
};

(: ======================================================================
   Creates an Order in the 3rd party Poll service
   ======================================================================
:)
declare function local:test2 ( ) {
  let $order := 
      <Order>
        <Id>TEST</Id>
        <Questionnaire lang="en">cctracker-sme-feedback</Questionnaire>
        <Variables>
          <Variable Key="kam">Mr System Test</Variable>
          <Variable Key="contact">Ms Contact Person</Variable>
          <Variable Key="contact-email">contact.person@nowhere.com</Variable>
        </Variables>
      </Order>
  return
    services:post-to-service('poll', 'poll.orders', $order, ("200", "201"))
};

(: ======================================================================
   Launch Evaluation service 
   NOTE: you must adjust '333' to a real Case in Closing status in your data set 
   ======================================================================
:)
declare function local:test3 ( ) {
  let $case := fn:collection($globals:cases-uri)//Case[No eq '333']
  let $activity := $case//Activity[No eq '1']
  return 
    evaluation:launch-feedback($case, $activity)
};


(: ======================================================================
   Launch Evaluation service 
   NOTE: you must adjust Order Id and Secret to the one in the Activity
   you have put in SME feedback status before runing this test 
   ======================================================================
:)
declare function local:test4 ( ) {
  let $order := 
    <Order>
      <Id>643a43917e27e803c3fa7fbab072a138</Id>
      <Secret>87d672a0c962c8a24354e4717ad86dfb</Secret>
      <Answers LastModification="2015-08-31T12:47:19.439+02:00">
              <ContactEmail>s.sire@free.fr</ContactEmail>
              <RatingScaleRef For="SME1">3</RatingScaleRef>
              <RatingScaleRef For="SME2">4</RatingScaleRef>
              <RatingScaleRef For="SME3">2</RatingScaleRef>
              <RatingScaleRef For="SME4">4</RatingScaleRef>
              <RatingScaleRef For="SME5">2</RatingScaleRef>
              <RatingScaleRef For="SME6">3</RatingScaleRef>
              <RatingScaleRef For="SME7">3</RatingScaleRef>
              <Comments>
          <Text>I have tested the feedback form</Text>
          <Text>And that seems to work great !</Text>
        </Comments>
      </Answers>
    </Order>
  return 
    evaluation:submit-answers($order)
};

(: MAIN ENTRY POINT :)
<site:views>
  <site:content>
    <p>Use '.xml' to see source of results</p>
    <pre>
      { local:test4() }
    </pre>
  </site:content>
</site:views>
