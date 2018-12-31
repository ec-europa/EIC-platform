xquery version "1.0";


(:==============================================
  PRE: EIC-1-call-upgrade has been fully applied
  beforehand
  ==============================================
:)

declare function local:create-project-collection( $date as xs:string, $id as xs:string ) as xs:string* {
  (: FIXME: use a @LastIndex scheme :)
    let $year := substring($date, 7, 4)
    let $month := substring($date, 4, 2)
    let $bootstrap := xmldb:create-collection('/db/sites/cctracker', 'projects')
    let $home-year-col-uri := concat('/db/sites/cctracker/projects', '/', $year)
    let $ts-year-col-uri := concat('/db/sites/cctracker/timesheets', '/', $year)
    let $home-col-uri := concat($home-year-col-uri , '/', $month)
    let $ts-col-uri := concat($ts-year-col-uri , '/', $month)
    return (
      (: Lazy creation of home collection with YEAR :)
      if (not(xmldb:collection-available($home-year-col-uri))) then
        if (xmldb:create-collection('/db/sites/cctracker/projects', $year)) then
          xmldb:set-collection-permissions($home-year-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Lazy creation of home collection with YEAR :)
      if (not(xmldb:collection-available($ts-year-col-uri))) then
        if (xmldb:create-collection('/db/sites/cctracker/timesheets', $year)) then
          xmldb:set-collection-permissions($ts-year-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Lazy creation of home collection with MONTH :)
      if (not(xmldb:collection-available($home-col-uri))) then
        if (xmldb:create-collection($home-year-col-uri, $month)) then
          xmldb:set-collection-permissions($home-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Lazy creation of home collection with MONTH :)
      if (not(xmldb:collection-available($ts-col-uri))) then
        if (xmldb:create-collection($ts-year-col-uri, $month)) then
          xmldb:set-collection-permissions($ts-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Case collection creation :)
      let $ts-uri := concat($ts-col-uri, '/', $id)
      return
        if (not(xmldb:collection-available($ts-uri))) then
          if (xmldb:create-collection($ts-col-uri, string($id))) then
            let $perms := xmldb:set-collection-permissions($ts-uri, 'admin', 'users', util:base-to-integer(0774, 8))
            return
              ()
          else
            ()
        else
          (),
      let $col-uri := concat($home-col-uri, '/', $id)
      return
        if (not(xmldb:collection-available($col-uri))) then
          if (xmldb:create-collection($home-col-uri, string($id))) then
            let $perms := xmldb:set-collection-permissions($col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
            return
              ($col-uri, string($id))
          else
            ()
        else
          ($col-uri, string($id))
      )
};

let $cases := collection('/db/sites/cctracker/cases')
return
  for $c in $cases//Case[Information/Call/SMEiCallRef ne '']
  let $ts := $c//Activity//TimesheetFile
  let $new :=
    <Project>
      <Id>{ string($c/@ProjectId) }</Id>
      { $c/CreationDate }
      <FormerCaseNo>{ $c/No/text() }</FormerCaseNo>
      <StatusHistory>
        <CurrentStatusRef>1</CurrentStatusRef>
        <Status>
          <Date>{ $c/CreationDate }</Date>
          <ValueRef>1</ValueRef>
        </Status>
      </StatusHistory>
      <Information>
        { $c/Information/*[not(local-name(.) = ('ClientEnterprise','ContactPerson', 'ManagingEntity'))] }
        <Beneficiaries>
          <Coordinator>
            <PIC>{ string($c/Information/ClientEnterprise/@EnterpriseId) }</PIC>
            { $c/Information/ClientEnterprise/* }
            { $c/Information/ContactPerson }
          </Coordinator>
        </Beneficiaries>
      </Information>
      <Cases LastIndex="1">
        <Case>
          <No>1</No>
          <PIC>{ string($c/Information/ClientEnterprise/@EnterpriseId) }</PIC>
          { $c/Information/ManagingEntity }
          { $c/*[not(local-name(.) = ('No', 'Information', 'CreationDate'))] }
        </Case>
      </Cases>
    </Project>
  let $datecall := collection('/db/sites/cctracker/global-information')//Selector[@Name eq 'SMEiCalls']//Name[../Code eq $c/Information/Call/SMEiCallRef]
  where not(collection('/db/sites/cctracker/projects')//Project[Id eq $c/@ProjectId])
  return
    let $res := local:create-project-collection($datecall, $new/Id )
    return
      (
      for $t in $ts
      let $src-uri := replace(util:collection-name($c),'cases','timesheets')
      let $target-uri := replace($res[1],'projects','timesheets')
      return xmldb:copy($src-uri, $target-uri, $t)
      ,
      let $store := xmldb:store($res[1], "project.xml", $new)
      return
        (
        xmldb:set-resource-permissions($res[1], "project.xml", 'admin', 'users', util:base-to-integer(0774, 8)),
        <Result>{$res[1], $new/Id}</Result>)[last()]
        )[last()]
    
