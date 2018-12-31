<?xml version="1.0" encoding="UTF-8" ?>
<!--
     XQuery Content Management Library

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Supergrid transformation entry point

     Copy this file into your project to extend supergrid with your own vocabulary/modules

     April 2017 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns="http://www.w3.org/1999/xhtml"
  >

  <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes" />

  <!-- Inherited from Oppidum pipeline -->
  <xsl:param name="xslt.base-url"></xsl:param>

  <!-- Query "goal" parameter transmitted by Oppidum pipeline -->
  <xsl:param name="xslt.goal">test</xsl:param>

  <!-- Transmitted by formulars/install.xqm-->
  <xsl:param name="xslt.base-root"></xsl:param> <!-- for Include -->

  <!-- Transmitted by formulars/install.xqm-->
  <xsl:param name="xslt.app-name">pilote</xsl:param>
  <xsl:param name="xslt.base-formulars">webapp/projects/cockpit/formulars/</xsl:param> <!-- for Include -->

  <!-- CONFIGURE these paths if you change XCM folder name ! -->
  <xsl:include href="../../../xcm/modules/formulars/search-mask.xsl"/>
  <xsl:include href="../../../xcm/modules/formulars/supergrid-core.xsl"/>
  
  <xsl:template match="Link">
    <xsl:value-of select="@Prefix"/><a href="{$xslt.base-url}{@Path}" target="_blank"><xsl:value-of select="."/></a><xsl:value-of select="@Suffix"/>
  </xsl:template>
  
  <xsl:template match="Column">
    <xsl:variable name="W"><xsl:choose><xsl:when test="@W"><xsl:value-of select="@W"/></xsl:when><xsl:otherwise>12</xsl:otherwise></xsl:choose></xsl:variable>
    <div class="span{$W}">
      <xsl:apply-templates select="*"/>
    </div>
  </xsl:template>
  
</xsl:stylesheet>  
