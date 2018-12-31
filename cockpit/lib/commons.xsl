<?xml version="1.0" encoding="UTF-8"?>
<!--
     Cockpit - EIC XQuery Content Management Framework

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Common widget vocabulary for generic platform level user interface

     Last update: 2016-11-25

     November 2016 - European Union Public Licence EUPL
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:variable name="smallcase" select="'abcdefghijklmnopqrstuvwxyz'" />
  <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />

  <!-- *********************************************** -->
  <!--  Common micro-format and attributes generators  -->
  <!-- *********************************************** -->

  <xsl:template match="@Id">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- FIXME: button initial state currently only 'disabled'-->
  <xsl:template match="@State[. = 'disabled']">
    <xsl:attribute name="disabled">disabled</xsl:attribute>
  </xsl:template>

  <xsl:template match="@Target">
    <xsl:attribute name="data-target"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>
  
  <xsl:template match="@EventTarget">
    <xsl:attribute name="data-event-target"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@Command">
    <xsl:attribute name="data-command"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- Confirmation popup dialog -->
  <xsl:template match="Confirm">
    <xsl:attribute name="data-confirm"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Template" mode="data-with-template">
    <xsl:attribute name="data-with-template"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Controller" mode="data-src">
    <xsl:attribute name="data-src"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- FIXME: align with XCM Display/ResourceNo or implement ^URL synbtax -->
  <xsl:template match="@ResourceName" mode="rn-base-url"><xsl:value-of select="."/><xsl:text>/</xsl:text>
  </xsl:template>

  <xsl:template match="Initialize" mode="data-init">
    <xsl:attribute name="data-init"><xsl:apply-templates select="ancestor::Page/@ResourceName" mode="rn-base-url"/><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Resource" mode="data-src">
    <xsl:attribute name="data-src"><xsl:apply-templates select="ancestor::Page/@ResourceName" mode="rn-base-url"/><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Controller" mode="data-src">
    <xsl:attribute name="data-src"><xsl:apply-templates select="ancestor::Page/@ResourceName" mode="rn-base-url"/><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@TargetEditor" mode="data-target-modal">
    <xsl:attribute name="data-target-modal"><xsl:value-of select="."/>-modal</xsl:attribute>
  </xsl:template>

  <!-- ************************************ -->
  <!--  <Label> for localization of parent  -->
  <!-- ************************************ -->

  <xsl:template match="Label">
    <xsl:copy-of select="@loc | @style"/>
    <xsl:value-of select="."/>
  </xsl:template>

  <!-- ****************************************** -->
  <!--                 TOP LEVEL                  -->
  <!-- ****************************************** -->

  <xsl:template match="Page">
    <site:view>
      <xsl:copy-of select="@skin"/>
      <xsl:if test="@Layout">
        <site:layout><xsl:value-of select="@Layout"/></site:layout>
      </xsl:if>
      <xsl:if test="not(@Layout)">
        <site:layout>ecl-container</site:layout>
      </xsl:if>
      <xsl:apply-templates select="*"/>
    </site:view>
  </xsl:template>

  <!-- ****************************************** -->
  <!--                PAGE CONTENT                -->
  <!-- ****************************************** -->
  
  <xsl:template match="Window">
    <site:window>
      <title><xsl:copy-of select="@loc"/><xsl:value-of select="."/></title>
    </site:window>
  </xsl:template>

  <!-- Model implies page title should be defined in Navigation/Name  -->
  <xsl:template match="Model">
    <xsl:if test="Navigation/Name">
      <site:title><xsl:value-of select="Navigation/Name"/></site:title>
    </xsl:if>
    <site:model>
      <xsl:copy-of select="*"/>
    </site:model>
  </xsl:template>

  <xsl:template match="Header">
    <site:header>
      <xsl:apply-templates select="*"/>
    </site:header>
  </xsl:template>
  
  <!-- Content may define a page title with an internal Title if Model is missing -->
  <xsl:template match="Content">
    <site:content>
      <xsl:apply-templates select="*"/>
    </site:content>
  </xsl:template>

  <xsl:template match="Overlay">
    <site:overlay>
      <xsl:apply-templates select="*"/>
    </site:overlay>
  </xsl:template>

  <xsl:template match="Verbatim">
    <xsl:apply-templates select="@* | *"/>
  </xsl:template>

  <xsl:template match="Views">
    <xsl:apply-templates select="@* | *"/>
  </xsl:template>

  <xsl:template match="View">
    <div>
      <xsl:apply-templates select="@* | *"/>
    </div>
  </xsl:template>
  
  <!-- TODO: factorize with Supergrid -->
  <xsl:template match="Title">
    <xsl:element name="h{@Level}">
      <xsl:copy-of select="@loc|@style|@class"/>
      <xsl:apply-templates select="@Offset"/>
      <xsl:apply-templates select="* | text()"/>
    </xsl:element>
  </xsl:template>
  
  <!-- FIXME: conflict if @style in Label, parameterize margin -->
  <xsl:template match="SpinningWheel">
    <p class="xcm-busy" style="display:none">
      <xsl:apply-templates select="@Id"/>
      <xsl:apply-templates select="Label"/>
    </p>
  </xsl:template>
  
</xsl:stylesheet>
