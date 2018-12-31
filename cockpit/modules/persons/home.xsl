<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>

  <!-- TODO: move to commons.xsl ? -->
  <xsl:template match="error" priority="1">
    <h2>Oops !</h2>
  </xsl:template>

  <xsl:template match="Mosaic">
    <div class="ecl-container">
      <div class="ecl-row">
      <xsl:apply-templates select="Tile"/>
      </div>
    </div>
  </xsl:template>
  
  <!-- inactive Tile -->
  <xsl:template match="Tile">
    <div style="display:none">
      <h2>
        <xsl:copy-of select="@loc"/>
        <xsl:value-of select="@loc"/>
      </h2>
    </div>
  </xsl:template>

  <!-- active Tile -->
  <xsl:template match="Tile[Link|Token]">
    <xsl:variable name="base">
      <xsl:if test="not(starts-with(Link,'http'))"><xsl:value-of select="$xslt.base-url"/></xsl:if>
    </xsl:variable>
    <div class="ecl-col-md-4 section__item">
      <div class="listing listing--navigation">
        <h2 class="listing__item-title">
          <xsl:if test="Token/Comment">
            <xsl:attribute name="style">top:20px</xsl:attribute>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="Token"><xsl:copy-of select="@loc"/><xsl:value-of select="@loc"/></xsl:when>
            <xsl:otherwise><a class="listing__item-link" loc="{@loc}" href="{ $base }{ Link }"><xsl:value-of select="@loc"/></a></xsl:otherwise>
          </xsl:choose>
        </h2>
        <div class="listing__section-description">
          <xsl:apply-templates select="Token"/>
          <xsl:apply-templates select="Subtitle">
            <xsl:with-param name="base"><xsl:value-of select="$base"/></xsl:with-param>
          </xsl:apply-templates>
        </div>
      </div>
    </div>
  </xsl:template>

  <!-- plain text SubTitle -->
  <xsl:template match="Subtitle">
    <div style="font-weight:bold"><xsl:value-of select="."/></div>
  </xsl:template>

  <!-- linkable SubTitle -->
  <xsl:template match="Subtitle[@Link = 'yes']" priority="1">
    <xsl:param name="base"/>
    <div style="font-weight:bold;"><a class="tile" href="{ $base }{ ../Link }"><xsl:value-of select="."/></a></div>
  </xsl:template>

  <!-- token request, note : Info and Request are exclusive -->
  <xsl:template match="Token[not(Comment)]">
    <div>
      <xsl:apply-templates select="Request"/>
      <xsl:value-of select="Info"/>
    </div>
  </xsl:template>

  <xsl:template match="Token[Comment]">
    <div>
      <xsl:apply-templates select="Request"/>
      <xsl:value-of select="Info"/>
    </div>
    <xsl:apply-templates select="Comment"/>
  </xsl:template>

  <xsl:template match="Request">
    <a class="tile" data-command="confirm" data-confirm-payload="Request" data-src="{@Controller}" style="cursor:pointer"><xsl:value-of select="."/></a><xsl:if test="../Info"><br/></xsl:if>
  </xsl:template>

  <xsl:template match="Comment">
    <div style="font-weight:bold;font-size:75%;"><xsl:value-of select="."/></div>
  </xsl:template>

</xsl:stylesheet>