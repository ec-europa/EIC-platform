<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/WhoIs[not(Role)]">
    <div id="results">
      <p>No role defined in database global configuration</p>
    </div>
  </xsl:template>

  <xsl:template match="/WhoIs">
    <div>
      <xsl:apply-templates select="Role"/>
    </div>
  </xsl:template>

  <xsl:template match="Role">
    <h4><xsl:value-of select="Title"/></h4>
    <xsl:apply-templates select="Persons/Person"/>
  </xsl:template>

  <!-- <h4><xsl:value-of select="Title"/></h4>
  <p><i>Not yet assigned at current workflow status</i></p> -->
  <xsl:template match="Role[None]">
  </xsl:template>

  <xsl:template match="Person">
    <p>
      <xsl:value-of select="normalize-space(Name)"/><xsl:apply-templates select="Function"/><xsl:apply-templates select="Enterprise"/><xsl:apply-templates select="ancestor::Role/@Mail"/><xsl:apply-templates select="Contacts/Email"/>
    </p>
  </xsl:template>

  <xsl:template match="Person[Service or RegionalEntity]">
    <p>
      <xsl:value-of select="Name"/>, <xsl:value-of select="Service | RegionalEntity"/><xsl:apply-templates select="ancestor::Role/@Mail"/><xsl:apply-templates select="Contacts/Email"/>
    </p>
  </xsl:template>

  <xsl:template match="@Mail | Email"><xsl:text> </xsl:text><i class="icon-envelope"></i> <a href="mailto:{.}"><xsl:value-of select="."/></a>
  </xsl:template>

  <xsl:template match="Email[ancestor::Role/@Mail]">
  </xsl:template>

  <xsl:template match="Function | Phone | Mobile"><xsl:text>, </xsl:text><xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Enterprise"><xsl:text>, </xsl:text><xsl:value-of select="Name"/>
  </xsl:template>

  <xsl:template match="Enterprise[WebSite]"><xsl:text>, </xsl:text>
    <a target="_blank">
      <xsl:apply-templates select="WebSite"/>
      <xsl:value-of select="Name"/>
    </a>
  </xsl:template>

  <!-- Generates URL to access WebSite URL as an href attribute -->
  <xsl:template match="WebSite">
    <xsl:attribute name="href">
      <xsl:choose>
        <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')"><xsl:value-of select="."/></xsl:when>
        <xsl:otherwise><xsl:value-of select="concat('http://', .)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
