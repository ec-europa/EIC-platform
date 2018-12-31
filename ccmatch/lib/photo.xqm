xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utilities to write (and downscale) image file to database
   with or without creating a side thumb image file

   Note that for some images the function get-height, get-width or scale print an error and do
   nothing, This happen for instance if they are in CYMK color space, in that case the script
   does not create a thumb.

   Mapping's level parameters: (set with <param name="name">value</param>)
   - max-size (HxW) : scales image to that size if it is bigger
   - thumb-size (HxW) : must be set to generate a thumb image file
   - thumb ("explicit") : when set to "explicit" thumb created if and only if the POST request
                          has a ?thumb parameter set (any value)

   NOTE : does not create a thumb if upoaded file is already below thumb-size

   Request's level parameters:
   - thumb=* : asks explicitly for thumb create when mapping's thumb parameter is set
     to explicit and when mapping's thumb-size is defined

   November 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace photo = "http://oppidoc.com/oppidum/photo";

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace image = "http://exist-db.org/xquery/image";
import module namespace text = "http://exist-db.org/xquery/text";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";

(: ======================================================================
   Converts a pre-defined request attribute representing a geometry string
   such as '100x200' (HxW) into a pair of integers. Return empty sequence
   if conversion fail or the attribute is missing from the request.
   FIXME: return error message to client !
   ======================================================================
:)
declare function photo:get-height-by-width( $geometry as xs:string? ) as xs:integer*
{
  if ($geometry and ($geometry != 'unset')) then
    let $seq := tokenize($geometry, 'x')
    return
      if (($seq[1] castable as xs:integer) and ($seq[2] castable as xs:integer)) then
        (xs:integer($seq[1]), xs:integer($seq[2]))
      else
        oppidum:debug(('photo:get-height-by-width with wrong parameter : ', $geometry))
  else
    ()
};

(: ======================================================================
   Checks if the $data must be downscale according to the $constraint
   Returns a pair where the first item is true() if the $data has been
   downscaled and false otherwise, and the second item is the $data if
   no downscaling was required or either the result of downscaling
   if it succeeded or () otherwise
   ======================================================================
:)
declare function photo:downscale( $constraint as xs:string, $id as xs:string, $mime-type as xs:string, $data as xs:base64Binary ) as item()*
{
  let $max-size := photo:get-height-by-width($constraint)
  return
    if (count($max-size) > 1) then
      let $width := image:get-width($data)
      let $height := if ($width) then image:get-height($data) else ()
      let $need-scaling := ($width and $height) and (($width > $max-size[1]) or ($height > $max-size[2]))
      (:let $log := oppidum:debug(('photo:downscale ', string($id), ' dimensions ', string($width),
       'x', string($height), ' needs scaling to ', $constraint, '(', string($max-size[1]),
       'x', string($max-size[2]), ')', ' is ', string($need-scaling))):)
      return
        if ($need-scaling) then
          let $res := image:scale($data, $max-size, $mime-type)
          return
            if ($res instance of xs:base64Binary) then
              (true(), $res)
            else
              (true(), ()) (: failure while downscaling :)
        else
          (false(), $data) (: no need to dowscale :)
    else
      (false(), $data) (: no need to dowscale :)
};

(: ======================================================================
   Creates the image file into the database and update the LastIndex
   Generates the file name from the $cur-index.
   Pre-condition: $cur-index attribute MUST contain a number
   ======================================================================
:)
declare function photo:write (
  $col-uri as xs:string,
  $user as xs:string,
  $group as xs:string,
  $data as xs:base64Binary,
  $id as xs:string,
  $extension as xs:string,
  $perms as xs:string ) as xs:string?
{
  let $filename := concat($id, '.', $extension)
  let $mime-type := concat('image/', $extension)
  let $max-size := request:get-attribute(concat('xquery.', 'max-size'))
  (:let $log := oppidum:debug(('call photo:write ', string($image-id), ' ', string($mime-type))),:)
  let $filtered := photo:downscale($max-size, $filename, $mime-type, $data)
  return
    if (($filtered[2] instance of xs:base64Binary)
        and (xdb:store($col-uri, $filename, $filtered[2], $mime-type))) then
      (
      compat:set-owner-group-permissions(concat($col-uri, '/', $filename), $user, $group, $perms),
      let $explicit := request:get-attribute(concat('xquery.', 'thumb')) eq 'explicit'
      let $thumb-size := request:get-attribute(concat('xquery.', 'thumb-size'))
      return
        if  ($thumb-size and (not($explicit) or ('thumb' = request:get-parameter-names()))) then
          (: prepare a thumb image if needed :)
          let $thumb := photo:downscale($thumb-size, $filename, $mime-type, $data)
          let $thumbname := concat($id, '-thumb.', $extension)
          return
            if (not(empty($thumb)) and $thumb[1] and ($thumb[2] instance of xs:base64Binary)) then
              if (xdb:store($col-uri, $thumbname, $thumb[2], $mime-type)) then
                compat:set-owner-group-permissions(concat($col-uri, '/', $thumbname), $user, $group, $perms)
              else
                () (: TODO: return a warning in case of error :)
            else
              () (: skip it, either no need to create a thumb or failure :)
        else
          (),
          $filename
      )[last()]
    else
      ()
};
