<?xml version="1.0" encoding="UTF-8"?>

<!-- CCTRACKER - EIC Case Tracker Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Modal view of Case information

     April 2015 - (c) Copyright may be reserved
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="Case">
    <div>
      <h2 style="margin-top:0"><span style="color:#08c"><xsl:value-of select="Acronym"/></span> : <xsl:value-of select="Title"/></h2>
      <p><b>Call</b> : <xsl:value-of select="Call/Date/@_Display"/> - Phase <xsl:value-of select="Call/PhaseRef/@_Display"/><xsl:apply-templates select="ClientEnterprise"/></p>
      <p><b>Topics</b> : <xsl:apply-templates select="Call/CallTopics/@_Display"/></p>
      <h3>Abstract</h3>
      <xsl:apply-templates select="Summary"/>
    </div>
  </xsl:template>

  <xsl:template match="NotFound">
    <p>Not Found</p>
  </xsl:template>

  <xsl:template match="ClientEnterprise"> - <xsl:apply-templates select="WebSite"/> (<xsl:value-of select="Country"/><xsl:apply-templates select="CreationYear|SizeRef"/>)
  </xsl:template>

  <xsl:template match="Text">
    <p><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="Summary[Text]">
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="CreationYear">, <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="SizeRef">, <xsl:value-of select="translate(@_Display, '()', ':')"/>
  </xsl:template>

  <!-- TODO: factorize -->
  <xsl:template match="WebSite">
    <a target="_blank">
      <xsl:attribute name="href">
        <xsl:choose>
          <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')"><xsl:value-of select="."/></xsl:when>
          <xsl:otherwise><xsl:value-of select="concat('http://', .)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </a>
  </xsl:template>

</xsl:stylesheet>
