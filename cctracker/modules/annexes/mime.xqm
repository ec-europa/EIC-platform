xquery version "1.0";
(: ------------------------------------------------------------------
   EIC Coaching Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Mime Type Utilities for file upload

   In particular this file defines the types of document you can upload 
   to the serveur using AXEL's 'file' plugin protocol
   
   NOTES :
   - you MUST align the $mime:types, $mime:extensions and $mime:export sequences
   - you MUST include a variant into the mapping for each supported extension 
   - you SHOULD configure AXEL's 'file' plugin in your XTiger templates to only submit 
     the same mime type with the file_type parameter

   February 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace mime = "http://platinn.ch/coaching/mime";

(: Accepted file extensions :)
declare variable $mime:extensions := ('pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx');

(: Accepted Mime Types :)
declare variable $mime:types := ('application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation');

(: Returned Mime Types - to help browser pick up the application in combination with compatible with Content-Disposition :)
declare variable $mime:export := ('application/pdf', 'application/msword', 'application/msword', 'application/vnd.ms-excel', 'application/vnd.ms-excel', 'application/vnd.ms-powerpoint', 'application/vnd.ms-powerpoint');

(: ======================================================================
   Returns the extension to use for a given mime type or () if not supported
   ======================================================================
:)
declare function mime:get-extension-for-mime( $mime as xs:string ) as xs:string*
{
  let $i := index-of($mime:types, $mime)
  return
    if ($i) then $mime:extensions[$i] else ()
};

(: ======================================================================
   Returns the mime type to use for a given extension or () if not supported
   ======================================================================
:)
declare function mime:get-mime-for-extension( $ext as xs:string ) as xs:string*
{
  let $i := index-of($mime:extensions, $ext)
  return
    if ($i) then $mime:export[$i] else ()
};
