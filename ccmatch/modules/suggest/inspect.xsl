<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Coach profile inspection to show in suggest tunnel

     November 2015 - (c) Copyright may be reserved
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="Coach">
    <div>
      <xsl:apply-templates select="CV-Link | CV-File"/>
      <h2>Coach profile for <xsl:apply-templates select="Civility"/><xsl:value-of select="Name"/></h2>
      <xsl:apply-templates select="Summary"/>
      <div id="cm-profile-part1" class="row-fluid">
        <div class="span4">
          <xsl:apply-templates select="SpokenLanguages"/>
        </div>
        <div class="span5">
          <xsl:apply-templates select="Experience"/>
        </div>
        <div class="span3">
          <xsl:apply-templates select="Address"/>
        </div>
      </div>
      <div id="cm-profile-part2">
        <xsl:apply-templates select="Skills"/>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="Summary">
    <p>
      <xsl:value-of select="."/>
    </p>    
  </xsl:template>

  <xsl:template match="CV-Link">
    <xsl:attribute name="data-cv-link"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- be carful to adjust link to mapping  -->
  <xsl:template match="CV-File">
    <xsl:attribute name="data-cv-file"><xsl:value-of select="../Id"/>/cv/<xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Civility"><xsl:value-of select="."/><xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Experience">
    <h3>Experience</h3>
    <p>
      <xsl:apply-templates select="IndustrialManagement"/>
      <xsl:apply-templates select="BusinessCoaching"/>
    </p>
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
    <h3>Location</h3>
    <address>
      <xsl:apply-templates select="Town"/>
      <xsl:apply-templates select="Country"/>
    </address>
  </xsl:template>

  <xsl:template match="Town">
    <xsl:value-of select='preceding-sibling::PostalCode'/><xsl:text> </xsl:text><xsl:value-of select='.'/>
  </xsl:template>

  <xsl:template match="Town[following-sibling::Country]">
    <xsl:value-of select='preceding-sibling::PostalCode'/><xsl:text> </xsl:text><xsl:value-of select='.'/><br/>
  </xsl:template>

  <xsl:template match="Country"><xsl:value-of select='@_Display'/>
  </xsl:template>

  <xsl:template match="SpokenLanguages">
    <h3>Languages</h3>
    <p><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="@Title" mode="header-caption"></xsl:template>

  <xsl:template match="@Title" mode="table-caption">
    <caption><xsl:value-of select="."/></caption>
  </xsl:template>

  <xsl:template match="@Title[ancestor::Inspect/@Mode = 'embed']" mode="header-caption">
    <h3><xsl:value-of select="."/></h3>
  </xsl:template>

  <xsl:template match="@Title[ancestor::Inspect/@Mode = 'embed']" mode="table-caption"></xsl:template>

  <xsl:template match="Skills[Skills]">
    <xsl:apply-templates select="@Title" mode="header-caption"/>
    <table class="table table-bordered">
      <xsl:apply-templates select="@Title" mode="table-caption"/>
      <thead>
        <tr>
          <th style="width:34%"></th>
          <th style="width:33%">Mid</th>
          <th style="width:33%">High</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select="Skills" mode="intra"/>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Skills[not(Skills)]">
    <xsl:apply-templates select="@Title" mode="header-caption"/>
    <table class="table table-bordered">
      <xsl:apply-templates select="@Title" mode="table-caption"/>
      <thead>
        <tr>
          <th style="width:50%">Mid</th>
          <th style="width:50%">High</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>
            <ul>
              <xsl:apply-templates select="Skill[. = '2']"/>
            </ul>
          </td>
          <td>
            <ul>
              <xsl:apply-templates select="Skill[. = '3']"/>
            </ul>
          </td>
        </tr>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template match="Skills" mode="intra">
    <tr>
      <td><xsl:value-of select="@For"/></td>
      <td>
        <ul>
          <xsl:apply-templates select="Skill[. = '2']"/>
        </ul>
      </td>
      <td>
        <ul>
          <xsl:apply-templates select="Skill[. = '3']"/>
        </ul>
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="Skill">
    <li><xsl:value-of select="@For"/></li>
  </xsl:template>
</xsl:stylesheet>

