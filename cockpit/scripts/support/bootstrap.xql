xquery version "3.0";
(: ------------------------------------------------------------------
  Description :
    SMED installation script for eXist v2.2 or superior
  
  Date : December 2018
   ------------------------------------------------------------------ :)

declare variable $local:crlf := codepoints-to-string((10));

declare option exist:serialize "method=text media-type=text/plain indent=yes";

(: Create "users" group :)
let $groups := sm:list-groups()
let $group := $groups[. = ('users')]
return 
  if ($group eq "users") then
    concat('Group "users" already exists', $local:crlf)
  else (
    sm:create-group('users'),
    concat('Created group "users"', $local:crlf)
    )
