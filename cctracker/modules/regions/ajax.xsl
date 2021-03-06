<?xml version="1.0" encoding="UTF-8"?>
<!-- CCTRACKER - EIC Case Tracker Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Table row generation for Ajax response to Regional Entity creation and/or update

     NOTE
     - errors raised via oppidum:throw-error that set a status code cut the pipeline and wont go through here

     January 2015 - European Union Public Licence EUPL
  -->
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="application/xml" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="region.xsl"/>

  <!--  Entry point coming from ajax:report-success() -->
  <xsl:template match="/success">
    <success>
      <xsl:copy-of select="message"/>
      <xsl:apply-templates select="payload"/>
    </success>
  </xsl:template>

  <!-- Ajax response with payload go through XSLT transformation to generate HTML fragments  -->
  <xsl:template match="payload">
    <payload>
      <xsl:apply-templates select="*"/>
    </payload>
  </xsl:template> 

</xsl:stylesheet>
