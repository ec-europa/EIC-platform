xquery version "1.0";
(: Copyright 2009-2011 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)

module namespace mmap = "http://oppidoc.com/oppidum/map";

declare namespace xsi="http://www.w3.org/2001/XMLSchema-instance";
declare namespace xs="http://www.w3.org/2001/XMLSchema";


declare function mmap:map() as element() {
  <map:map
   xmlns="http://oppidoc.com/oppidum/map" 
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
};

declare function mmap:put($map as element()?, $key as xs:anyAtomicType, $value as xs:anyAtomicType) as element() {
  let $entry :=
    <map:entry>
      <map:key xsi:type="xs:string">{ $key }</map:key>
      <map:value xsi:type="xs:string">{ $value }</map:value>
    </map:entry>
  return
    <map:map
    xmlns="http://oppidoc.com/oppidum/map" 
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xs="http://www.w3.org/2001/XMLSchema">
    {
      if ($map) then
        for $e in $map/*[local-name() = "entry"]
        return $e
      else (),
      $entry
    }
    </map:map>
};

declare function mmap:get($map as element(), $key as xs:anyAtomicType) as xs:anyAtomicType* {
  for $entry in $map/*[local-name() = "entry"]
  where $entry/map:key = $key
  return $entry/map:value
};

declare function mmap:coalesce($maps as element()*) as element() {
  <map:map
  xmlns="http://oppidoc.com/oppidum/map" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xs="http://www.w3.org/2001/XMLSchema">
  {
    for $e in $maps/child::*[local-name() = "entry"]
    return $e
  }
  </map:map>
};