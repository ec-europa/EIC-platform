(: run as # run as ./bin/client.sh -F sanity-check.xql -u admin -P password:)
(: to create a full database backup in data/export folder :)
let $parameters := 
  <parameters>
    <param name="output" value="export"/> 
    <param name="backup" value="yes"/> 
    <param name="incremental" value="no"/> 
    <param name="zip" value="yes"/>
  </parameters> 
return system:trigger-system-task("org.exist.storage.ConsistencyCheckTask", $parameters)
