<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>

  <xsl:template match="Content">
    <site:content>
      <div class="row">
        <xsl:apply-templates select="Verbatim"/>
        <div class="span12">
          <xsl:apply-templates select="Tabs"/>
        </div>
      </div>
      <xsl:apply-templates select="Modals"/>
    </site:content>
  </xsl:template>

  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="Management-ImportResults">
    <table id="cm-import-results" class="table table-bordered" data-command="import-table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Case Tracker</th>
          <th>Email</th>
          <th>Acceptance Status</th>
          <th>Working status</th>
          <th>Availability</th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>  
  </xsl:template>
  

</xsl:stylesheet>
