xquery version "3.0";
(: --------------------------------------
   EXCM - Deploy module

   Utility functions for writing deploy.xql script

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>

   December 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace deploy = "http://oppidoc.com/ns/deploy";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace install = "http://oppidoc.com/oppidum/install" at "../oppidum/lib/install.xqm";

(: ======================================================================
   Return true if every target is defined of false otherwise
   ====================================================================== 
:)
declare function deploy:targets-available( $targets as xs:string*, $code as element() ) as xs:boolean {
  exists($targets) and (
    let $explicit := $code/install:targets/install:target/@name
    let $implicit := distinct-values(($code/install:group/@incl, $code/install:group/@name))
    return
      every $t in $targets satisfies ($t = $explicit or $t = $implicit)
    )
};

(: ======================================================================
   Summarize list of possible targets for application deployment
   ====================================================================== 
:)
declare function deploy:gen-targets( $code as element() ) as xs:string {
  let $others := $code/install:targets/install:target/@name
  let $incl := distinct-values($code/install:group/@incl)
  return
    string-join(
      (
      $incl,
      $code/install:group[empty(@incl) or @incl != 'no']/@name,
      $others
      ), ','
    )
};

(: ======================================================================
   Special all target implementation : rewrite to a combination of targets
   ====================================================================== 
:)
declare function deploy:deploy-targets ( $code as element(), $policies as element(), $incl as xs:string, $dir as xs:string,  $base-url as xs:string, $mode as xs:string, $deploy ) {
  let $more := $code/install:targets/install:set[@name eq '*']/install:incl
  let $dependencies := $code/install:targets/install:set[@name eq $incl]/install:incl
  let $targets := distinct-values((
    for $set in ($incl, $dependencies)
    return $code/install:group[@incl eq $set]/string(@name),
    $code/install:targets/install:set[@name eq $incl]/install:target,
    $more
    ))
  return (
    <p>'{ $incl }' target bootstrapping : </p>,
    <ul>
      {
      for $c in $code/install:collection
      let $col := $c/string(@name)
      return
          if (xdb:collection-available($col)) then
            <li>{ $col } : already exists, skip creation</li>
          else (
            install:install-collection($dir, $c, ()),
            install:install-policy($c, $policies)
            )
      }
    </ul>,
    <p>Now executing '{ $incl }' target rewritten to => { string-join($targets, ',') }</p>,
    $deploy($dir, $targets, $base-url, $mode)
    )
};

