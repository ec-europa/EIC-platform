<?xml version="1.0" encoding="UTF-8"?>
<!-- CCTRACKER - EIC Case Tracker Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     XSL templates to generate Regional Entity table row in search results list

     January 2015 - European Union Public Licence EUPL
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:template match="RegionalEntity">
    <tr class="unstyled" data-id="{Id}">
      <td>
        <xsl:apply-templates select="Acronym"/>
      </td>
      <td>
        <xsl:apply-templates select="Country"/>
      </td>
      <td>
        <xsl:apply-templates select="Managers/Manager"/>
      </td>
      <td>
        <xsl:apply-templates select="KAMs/KAM"/>
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="Acronym">
    <xsl:variable name="update"><xsl:if test="ancestor::*[@Update = 'y']">!</xsl:if></xsl:variable>
    <a>
      <span data-src="{$update}regions/{../Id}">
        <xsl:value-of select="."/>
      </span>
    </a>
  </xsl:template>

  <xsl:template match="Country">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Manager | KAM">
    <a data-toggle="modal" href="persons/{.}.modal" data-target="#person-modal"><xsl:value-of select="@_Display"/></a><xsl:text>, </xsl:text>
  </xsl:template>

  <xsl:template match="Manager[position() = last()] | KAM[position() = last()]">
    <a data-toggle="modal" href="persons/{.}.modal" data-target="#person-modal"><xsl:value-of select="@_Display"/></a>
  </xsl:template>

  <!-- <xsl:template match="WebSite">
      <a target="_blank">
        <xsl:attribute name="href">
          <xsl:choose>
            <xsl:when test="starts-with(., 'http://') or starts-with(., 'https://')"><xsl:value-of select="."/></xsl:when>
            <xsl:otherwise><xsl:value-of select="concat('http://', .)"/></xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:value-of select="."/>
      </a>
    </xsl:template> -->

</xsl:stylesheet>
