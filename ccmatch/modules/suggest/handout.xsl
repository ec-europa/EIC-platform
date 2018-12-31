<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach summary to show in suggest tunnel

     October 2015 - (c) Copyright may be reserved
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">test</xsl:param>
  <xsl:variable name="xslt.avatar-path">static/ccmatch/images/avatar.png</xsl:variable>

  <!-- Note: hard-coded trick to duplicate Back button at the top ! -->
  <xsl:template match="Handout">
    <div>
      <div class="noprint" style="float:right">
        <button class="btn btn-primary" onclick="javascript:window.print();">Print</button>
        <button class="btn btn-primary" onclick="javascript:$('#back-in-handout').click()">Back</button>
      </div>
      <h2 style="line-height:1;margin-top: 1em">Coach suggestions<xsl:apply-templates select="Acronym"/></h2>
      <xsl:apply-templates select="Coach"/>
    </div>
  </xsl:template>

  <xsl:template match="Acronym"><xsl:text> </xsl:text> for <xsl:value-of select="."/>
      <xsl:apply-templates select="../Title"/>
  </xsl:template>

  <xsl:template match="Title"><br/>
    <span style="font-size:65%">(<xsl:value-of select="."/>)</span>
  </xsl:template>

  <xsl:template match="Coach">
    <table class="table table-bordered cm-handout">
      <xsl:if test="position() mod 2 = 1">
        <xsl:attribute name="style">clear:left</xsl:attribute>
      </xsl:if>
      <tr>
        <td class="cm-handout-label">Name</td>
        <td><b><xsl:apply-templates select="Civility"/><xsl:value-of select="Name"/></b></td>
        <td rowspan="4" style="padding:0;width:150px;height:150px;border-left:none"><xsl:apply-templates select="Photo"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">Phone</td>
        <td><xsl:value-of select="Phone"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">Mobile</td>
        <td><xsl:value-of select="Mobile"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">Skype</td>
        <td><xsl:value-of select="Skype"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">E-mail</td>
        <td colspan="2"><xsl:apply-templates select="Email"/></td>
      </tr>
      <tr style="height:260px">
        <td class="cm-handout-label">Executive summary</td>
        <td colspan="2"><xsl:value-of select="Summary"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">Competence Fit</td>
        <td colspan="2" style="width:300px;height:280px">
          <script type="application/json" style="display:none" class="cm-radar">
            <xsl:value-of select="Competence"/>
          </script>
          <div class="cm-radar"/>
        </td>
      </tr>
      <tr>
        <td class="cm-handout-label">CV</td>
        <td colspan="2"><xsl:apply-templates select="CV-Link"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label" style="height:3em">Location</td>
        <td colspan="2"><xsl:apply-templates select="Address"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">Language(s)</td>
        <td colspan="2"><xsl:value-of select="Languages"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label" style="height:3em">Experience</td>
        <td colspan="2">
          <xsl:apply-templates select="Experience/IndustrialManagement"/><br/>
          <xsl:apply-templates select="Experience/BusinessCoaching"/>
        </td>
      </tr>
      <!-- <tr>
        <td class="cm-handout-label">Industrial mgt. experience</td>
        <td colspan="2"><xsl:value-of select="Experience/IndustrialManagement"/></td>
      </tr>
      <tr>
        <td class="cm-handout-label">Business coaching experience</td>
        <td colspan="2"><xsl:value-of select="Experience/BusinessCoaching"/></td>
      </tr> -->
    </table>
  </xsl:template>
  
  <xsl:template match="Photo">
    <img src="{.}" style="max-width:150px;max-height:150px"/>
  </xsl:template>

  <xsl:template match="Photo[ . = '']">
    <img src="{$xslt.base-url}{$xslt.avatar-path}" style="width:150px;height:150px"/>
  </xsl:template>

  <xsl:template match="Civility"><xsl:value-of select="."/><xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="CV-Link">
    <span class="ellipsis">
    <xsl:choose>
      <xsl:when test="starts-with(., 'http:') or starts-with(., 'https:')">
        <a href="{.}" target="_blank"><xsl:value-of select="."/></a>
      </xsl:when>
      <xsl:otherwise>
        <a href="{.}">http://<xsl:value-of select="."/></a>
      </xsl:otherwise>
    </xsl:choose>
    </span>
  </xsl:template>

  <xsl:template match="Email">
    <a href="mailto:{.}"><xsl:value-of select="."/></a>
  </xsl:template>

  <xsl:template match="Address">
    <xsl:apply-templates select="Town"/><xsl:apply-templates select="Country"/>
  </xsl:template>

  <xsl:template match="Town">
    <xsl:value-of select='preceding-sibling::PostalCode'/><xsl:text> </xsl:text><xsl:value-of select='.'/>
  </xsl:template>

  <xsl:template match="Town[following-sibling::Country]">
    <xsl:value-of select='preceding-sibling::PostalCode'/><xsl:text> </xsl:text><xsl:value-of select='.'/><br/>
  </xsl:template>

  <xsl:template match="Country"><xsl:value-of select='@_Display'/>
  </xsl:template>

  <xsl:template match="IndustrialManagement"><xsl:value-of select='.'/> in industrial management
  </xsl:template>

  <xsl:template match="BusinessCoaching"><xsl:value-of select='.'/> in business coaching
  </xsl:template>

</xsl:stylesheet>
