<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach summary to show in suggest tunnel

     October 2015 - (c) Copyright may be reserved
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>
  
  <xsl:template match="Coach">
    <h2><xsl:apply-templates select="Civility"/><xsl:value-of select="Name"/></h2>
    <ul class="cm-summary">
      <li>
        <h3>Contacts</h3>
        <dl>
          <xsl:apply-templates select="CV-Link"/>
          <xsl:apply-templates select="Email"/>
          <xsl:apply-templates select="Mobile"/>
          <xsl:apply-templates select="Phone"/>
          <xsl:apply-templates select="Skype"/>
        </dl>
      </li>
      <xsl:apply-templates select="Experience"/>
      <xsl:apply-templates select="Address"/>
    </ul>
  </xsl:template>
  
  <xsl:template match="CV-Link">
    <dt>CV</dt>
    <dd>
      <span class="ellipsis" style="width:400px">
        <xsl:choose>
          <xsl:when test="starts-with(., 'http:') or starts-with(., 'https:')">
            <a href="{.}" target="_blank"><xsl:value-of select="."/></a>
          </xsl:when>
          <xsl:otherwise>
            <a href="{.}">http://<xsl:value-of select="."/></a>
          </xsl:otherwise>
        </xsl:choose>
      </span>
    </dd>
  </xsl:template>

  <xsl:template match="Email">
    <dt>E-mail</dt>
    <dd><a href="mailto:{.}"><xsl:value-of select="."/></a></dd>
  </xsl:template>

  <xsl:template match="Mobile">
    <dt>Mobile</dt>
    <dd><xsl:value-of select="."/></dd>
  </xsl:template>

  <xsl:template match="Phone">
    <dt>Phone</dt>
    <dd><xsl:value-of select="."/></dd>
  </xsl:template>

  <xsl:template match="Skype">
    <dt>Skype</dt>
    <dd><xsl:value-of select="."/></dd>
  </xsl:template>

  <xsl:template match="Civility"><xsl:value-of select="."/><xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Experience">
    <li>
      <h3>Experience</h3>
      <p>
        <xsl:apply-templates select="IndustrialManagement"/>
        <xsl:apply-templates select="BusinessCoaching"/>
      </p>
    </li>
  </xsl:template>

  <xsl:template match="IndustrialManagement">
    <xsl:value-of select='.'/> in industrial management position
  </xsl:template>

  <xsl:template match="IndustrialManagement[following-sibling::BusinessCoaching]">
    <xsl:value-of select='.'/> in industrial management position<br/>
  </xsl:template>

  <xsl:template match="BusinessCoaching">
    <xsl:value-of select='.'/> in business coaching
  </xsl:template>

  <xsl:template match="Address">
    <li>
      <h3>Location</h3>
      <address>
        <xsl:apply-templates select="Town"/>
        <xsl:apply-templates select="Country"/>
      </address>
    </li>
  </xsl:template>

  <xsl:template match="Town">
    <xsl:value-of select='preceding-sibling::PostalCode'/><xsl:text> </xsl:text><xsl:value-of select='.'/>
  </xsl:template>

  <xsl:template match="Town[following-sibling::Country]">
    <xsl:value-of select='preceding-sibling::PostalCode'/><xsl:text> </xsl:text><xsl:value-of select='.'/><br/>
  </xsl:template>

  <xsl:template match="Country"><xsl:value-of select='@_Display'/>
  </xsl:template>

</xsl:stylesheet>
