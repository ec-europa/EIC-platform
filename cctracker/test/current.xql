import module namespace access = "http://oppidoc.com/oppidum/access" at "../lib/access.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../lib/form.xqm";
import module namespace enterprise = "http://oppidoc.fr/ns/ctracker/enterprise" at "../modules/enterprises/enterprise.xqm";

declare function local:diff-enterprises( $e1 as element(), $e2 as element() ) as element()* {
  let $nodeset := $e1//*[count(./*) eq 0]
  return (
    for $n in $nodeset
    let $name := local-name($n)
    let $match := $e2//*[local-name(.) eq $name]
    where $name ne 'Id'
    return
      if (string($match) ne string($n)) then
        element { $name } {
          (
          <old>{string($n)}</old>,
          <new>{string($match)}</new> 
          )
        }
      else
        (),
    let $names := for $n in $nodeset return local-name($n)
    return
      for $n in $e2//*[(count(./*) eq 0) and not(local-name(.) = $names)]
      return
        element { local-name($n) } {
          (
          <old></old>,
          <new>{string($n)}</new> 
          )
        }
    )
};

(:access:get-function-ref-for-role(()):)
  
(:form:gen-person-with-role-selector('coach', 'en',
  "FOO", "span2")
:)

(:enterprise:gen-enterprise-for('261', 'en', 'read'):)

let $e1 := 
<Enterprise EnterpriseId="929894672">
  <Id>892</Id>
  <Name>Iceye Oy</Name>
  <ShortName>ICEYE Oy</ShortName>
  <CreationYear _Source="2014-09-15T23:55:44">2014</CreationYear>
  <SizeRef _Source="9">1</SizeRef>
  <WebSite>www.iceye.fi</WebSite>
  <Address>
    <StreetNameAndNo>Otsolahdentie 14 A 28</StreetNameAndNo>
    <Town>Espoo</Town>
    <PostalCode>2110</PostalCode>
    <Country>FI</Country>
  </Address>
</Enterprise>

let $e2 :=
<Enterprise EnterpriseId="929894672">
<Name>Iceye Oy</Name>
<ShortName>ICEYE Oy</ShortName>
<CreationYear _Source="2014-09-15T23:55:44">2014</CreationYear>
<SizeRef _Source="9">1</SizeRef>
<WebSite>www.iceye.fi</WebSite>
<Address>
<StreetNameAndNo>Otsolahdentie 14 A 28</StreetNameAndNo>
<Town>Espoo</Town>
<PostalCode>2110</PostalCode>
<Country>FI</Country>
</Address>
</Enterprise>

return 

let $diff := local:diff-enterprises($e1, $e2)
return
  if (count($diff) > 0) then
    <Diff Id="{$e1/Id}" EnterpriseId="{$e1/@EnterpriseId}">
      { $diff }
    </Diff>
  else
    <Same Id="{$e1/Id}" EnterpriseId="{$e1/@EnterpriseId}"/>
