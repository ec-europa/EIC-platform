<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../app/custom.xsl"/>
  
  <!-- TODO: finish ... role/function -->
  <xsl:template match="Name">
    <li><xsl:value-of select="FirstName"/><xsl:text> </xsl:text><xsl:value-of select="LastName"/> (Contact Person)</li>
  </xsl:template>

  <!-- Generates event application table for one company for one event programme -->
  <xsl:template match="EventApplicationList[Event]">
    <table class="ecl-table ecl-table-responsive xcm-search-results">
      <caption><xsl:value-of select="Programme"/></caption>
      <thead>
        <tr>
          <th style="width:20%">Name</th>
          <th style="width:25%">Topic</th>
          <th style="width:20%">Location</th>
          <th style="width:15%">Date</th>
          <th style="width:20%">
            <xsl:choose>
              <xsl:when test="@CanApply = 'true'">Application Status</xsl:when>
              <xsl:otherwise>Application Period</xsl:otherwise>
            </xsl:choose>
          </th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Event"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="EventApplicationList[not(Event)]">
  </xsl:template>

  <!-- Generates event management table -->
  <xsl:template match="EventManagementList">
    <table class="ecl-table ecl-table-responsive xcm-search-results">
      <caption><xsl:value-of select="Programme"/></caption>
      <thead>
        <tr>
          <th style="min-width:25%">Name</th>
          <th>Ranking List</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Event"/>
      </tbody>
    </table>
  </xsl:template>

  <!-- Generates event export table -->
  <xsl:template match="EventExportList">
    <table class="ecl-table ecl-table-responsive xcm-search-results">
      <caption><xsl:value-of select="Programme"/></caption>
      <xsl:apply-templates select="Statuses" mode="event"/>
      <xsl:apply-templates select="Event"/>
    </table>
  </xsl:template>

  <xsl:template match="Event[parent::EventApplicationList]">
    <tr>
      <td><xsl:apply-templates select="Name" mode="event"/><xsl:text> </xsl:text><xsl:apply-templates select="PublicationStateRef"/></td>
      <td><xsl:apply-templates select="Topic" mode="event"/> <xsl:apply-templates select="Resources"/></td>
      <td><xsl:apply-templates select="Location" mode="event"/></td>
      <td><xsl:apply-templates select="Date" mode="event"/></td>
      <td><xsl:apply-templates select="Application" mode="event"/></td>
    </tr>
  </xsl:template>

  <xsl:template match="Event[parent::EventManagementList]">
    <tr>
    <td style="width:50%;">
      <xsl:choose>
        <xsl:when test="Editable">
          <a class="link icon-edit" data-event="{Editable/@Link}" style="color:white;cursor:pointer;float:right">___</a><xsl:text> </xsl:text><xsl:apply-templates select="Name" mode="event"/><xsl:apply-templates select="PublicationStateRef"/>
        </xsl:when>
        <xsl:otherwise><xsl:apply-templates select="Name" mode="event"/><xsl:apply-templates select="PublicationStateRef"/></xsl:otherwise>
      </xsl:choose>
    </td>
    <td>
      <xsl:apply-templates select="Nothing | NotClosed | Evaluation | Confirmation | FinalizationStandBy | Finalization | Finalized | NotYet | ReOpened | Undefined"/>
    </td>
    </tr>
  </xsl:template>

  <!-- TODO: manage Topic if Name/@Export='Topic' -->
  <xsl:template match="Event[parent::EventExportList]">
    <tbody>
      <td><xsl:apply-templates select="Name" mode="event"/><xsl:apply-templates select="PublicationStateRef"/></td>
      <xsl:apply-templates select="Excels">
        <xsl:sort select="@For"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="Index" mode="event"/>
    </tbody>
  </xsl:template>

  <xsl:template match="PublicationStateRef[. = '1']"> -<i style="color:red"> Draft</i>
  </xsl:template>

  <xsl:template match="PublicationStateRef[. != '1']">
  </xsl:template>

  <xsl:template match="Name[not(../WebSite)]" mode="event"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Name[../WebSite]" mode="event"><a href="{ ../WebSite }" target="_blank"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="Name[@Extra = 'Topic'][ancestor::EventApplicationList]" mode="event" priority="1"><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Name[not(../WebSite)][@Extra = 'Topic'][ancestor::EventExportList or ancestor::EventExportList or ancestor::EventManagementList]" mode="event" priority="1"><xsl:value-of select="."/> : <xsl:value-of select="../Topic"/>
  </xsl:template>

  <xsl:template match="Name[../WebSite][@Extra = 'Topic'][ancestor::EventExportList]" mode="event" priority="1"><xsl:value-of select="."/> : <a href="{ ../WebSite }" target="_blank"><xsl:value-of select="../Topic"/></a>
  </xsl:template>

  <xsl:template match="Topic[. = '']" mode="event">To be defined
  </xsl:template>
  
  <xsl:template match="Topic[@File]" mode="event" priority="1"><a href="../files/{@File}" target="_blank"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="Topic[../Name/@Extra = 'Topic'][../WebSite != '']" mode="event" priority="1"><a href="{ ../WebSite }" target="_blank"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="Resources">
    <div class="accordion-group accordion-caret">
      <div class="accordion-heading">
        <a data-toggle="collapse" href="#exp{../Id}" style="display:block;">Documents</a>
      </div>
      <div id="exp{../Id}" class="accordion-body collapse">
        <blockquote>
          <xsl:apply-templates select="File"/>
        </blockquote>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="File">
    <a style="display:block" href="../files/{substring-before(.,'.')}" target="_blank"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="Location[. = '']" mode="event">To be defined
  </xsl:template>

  <xsl:template match="Date[. = '']" mode="event">To be defined
  </xsl:template>

  <xsl:template match="Application[. = '']" mode="event">To be defined
  </xsl:template>

  <xsl:template match="Application[@Link]" mode="event" priority="1"><a href="{ @Link }"><xsl:value-of select="."/></a>
  </xsl:template>

  <xsl:template match="Application[not(@Link)][@Satellite]" mode="event" priority="1.25"><xsl:value-of select="."/><xsl:text> </xsl:text> (<xsl:value-of select="@Satellite"/>)
  </xsl:template>

  <xsl:template match="Application[@Link][@Satellite]" mode="event" priority="1.25"><xsl:value-of select="."/> : <a href="{ @Link }"><xsl:value-of select="@Satellite"/></a><xsl:text> </xsl:text><xsl:apply-templates select="@On|@Since"/>
  </xsl:template>

  <xsl:template match="@On">on <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@Since">since <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Excels[not(Excel)]"><td/>
  </xsl:template>

  <xsl:template match="Excels">
    <td>
      <xsl:apply-templates select="Excel" mode="excels"/>
    </td>
  </xsl:template>

  <xsl:template match="Excel" mode="excels">
    <xsl:apply-templates select="." mode="event"/><xsl:if test="count(parent::Excels/Excel) gt 1"><xsl:text> </xsl:text>(<xsl:value-of select="@Category"/>)</xsl:if>
  </xsl:template>

  <!-- same with layout formating -->
  <xsl:template match="Excel[preceding-sibling::Excel]" priority="1.25" mode="excels">
    <div style="clear:both; border-top: dotted 1px gray; margin-top: 5px">
      <xsl:apply-templates select="." mode="event"/><xsl:if test="count(parent::Excels/Excel) gt 1"><xsl:text> </xsl:text>(<xsl:value-of select="@Category"/>)</xsl:if>
    </div>
  </xsl:template>

  <xsl:template match="Excel[not(@Link)]" mode="event">
  </xsl:template>

  <xsl:template match="Excel[not(@Link) and (@Draft or @Submitted)]" mode="event" priority="1">
    <xsl:apply-templates select="@Draft"/><xsl:value-of select="@Submitted"/> Submitted
  </xsl:template>

  <!-- <xsl:template match="Excel[@Link != '']" mode="event" priority="1">
    <td>
      <a target="_blank" class="btn btn-primary btn-small" href="{ @Link }">Export (<xsl:value-of select="@Draft"/> Drafts, <xsl:value-of select="@Submitted"/> Submitted)</a>
    </td>
  </xsl:template> -->

  <xsl:template match="Excel[@Link != '']" mode="event" priority="1.25">
     <a target="_blank" class="link" style="float:left;margin-right:10px" href="{ @Link }"><img src="{$xslt.base-url}static/cockpit/images/excel.png" alt="Excel" style="width:20px"/></a><xsl:text> </xsl:text><xsl:apply-templates select="@Draft"/><xsl:value-of select="@Submitted"/> Submitted
  </xsl:template>

  <xsl:template match="@Draft"><xsl:value-of select="."/> Drafts,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="@Draft[. = '0']" priority="1">
  </xsl:template>

  <xsl:template match="@Draft[. = '1']" priority="1">1 Draft,<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Index[not(@Link)]" mode="event"><td/>
  </xsl:template>

  <xsl:template match="Index[not(@Link) and @Submitted]" mode="event" priority="1">
    <td>
      <xsl:value-of select="@Submitted"/> Submitted
    </td>
  </xsl:template>

  <!-- actually no @Draft since this is not yet implemented for external feedbacks -->
  <xsl:template match="Index[@Link != '']" mode="event" priority="1.25">
    <td>
      <a target="_blank" href="{ @Link }"><xsl:value-of select="@Submitted"/> Submitted</a>
    </td>
  </xsl:template>

  <xsl:template match="Statuses" mode="event">
    <thead>
      <tr>
        <th style="width:25%">Name</th>
        <xsl:apply-templates select="Status" mode="event">
          <xsl:sort select="@Id"/>
        </xsl:apply-templates>
      </tr>
    </thead>
  </xsl:template>

  <xsl:template match="Status" mode="event">
    <th><xsl:value-of select="."/></th>
  </xsl:template>

  <!-- *************************************** -->
  <!-- Status Information for Event Management -->
  <!-- *************************************** -->
  
  <xsl:template match="Nothing">No application form has been submitted yet.</xsl:template>
  
  <xsl:template match="NotYet">Application period begins on <xsl:value-of select="@FirstDay"/></xsl:template>
  
  <xsl:template match="Undefined"><i style="color:red">Dates have not been properly defined. Please correct them.</i></xsl:template>
  
  <xsl:template match="NotClosed[@Submitted > 0]">The <xsl:value-of select="@Submitted"/> forms cannot be ranked yet as we are still within application period (ending <xsl:value-of select="@LastDay"/>).</xsl:template>
  
  <xsl:template match="NotClosed[@Submitted = 0]">No application form has been submitted yet (application ending <xsl:value-of select="@LastDay"/>).</xsl:template>

  <!-- interim period between reopening and closed again / available for ranking -->
  <xsl:template match="ReOpened">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Reopened ranking of <xsl:value-of select="@Submitted"/> submitted forms can be seen, ranking will be available after the application period (ending <xsl:value-of select="@LastDay"/>).</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="Evaluation[@Status = 'events-manager'][@Manager]">
    <xsl:call-template name="link">
      <xsl:with-param name="text"><xsl:value-of select="@Submitted"/> submitted forms ready for draft ranking!</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="Evaluation[@Status = 'events-manager'][@Supervisor]">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Draft ranking for the <xsl:value-of select="@Submitted"/> submitted forms can be done!</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="Confirmation[@Status = 'events-supervisor'][@Manager]">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Ranking of <xsl:value-of select="@Submitted"/> application ready for confirmation!</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="Confirmation[@Status = 'events-supervisor'][@Supervisor]">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Ranking awaiting confirmation for the <xsl:value-of select="@Submitted"/> applications!</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="FinalizationStandBy">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Awaiting confirmation/intent from <xsl:value-of select="@Submitted"/> selected applicants (<xsl:value-of select="@Elapsed"/> days elapsed)</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="Finalization[@Status = 'events-supervisor'][@Manager]">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Final Ranking of <xsl:value-of select="@Submitted"/> submitted forms is open!</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="Finalization[@Status = 'events-supervisor'][@Supervisor]">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Final Ranking awaiting confirmation for the <xsl:value-of select="@Submitted"/> submitted forms!</xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="Finalized[@Status = 'events-manager events-supervisor']">
    <xsl:call-template name="link">
      <xsl:with-param name="text">Ranking of <xsl:value-of select="@Submitted"/> applicants finalized.</xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="link">
    <xsl:param name="text"/>
    <xsl:choose>
      <xsl:when test="@Link">
        <a target="_blank"  href="{ @Link }"><xsl:value-of select="$text"/></a>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>