<?xml version="1.0" encoding="UTF-8"?>
<!-- Oppidum Application Framework

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Shared widget components

     Attempt to build a common widget vocabulary for Supergrid 
     and other UI components (eg. widget.xsl)

     May 2016 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xt="http://ns.inria.org/xtiger"
                xmlns:site="http://oppidoc.com/oppidum/site"
                xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output encoding="UTF-8" indent="yes" method="xml" />

<xsl:variable name="smallcase" select="'abcdefghijklmnopqrstuvwxyz'" />
<xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />

  <!-- ##################### -->
  <!--   Generic attributes  -->
  <!-- ##################### -->

  <!-- Implements @Role='secondary' on buttons -->
  <xsl:template name="button-class">
    <xsl:attribute name="class">
      <xsl:choose>
        <xsl:when test="@Role = 'secondary'">btn</xsl:when>
        <xsl:otherwise>btn btn-primary</xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="@Id">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@Target">
    <xsl:attribute name="data-target"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>
  
  <xsl:template match="@EventTarget">
    <xsl:attribute name="data-event-target"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>
  
  <!-- ################################ -->
  <!--   Generic commands for buttons   -->
  <!-- ################################ -->

  <!-- Direct 'onclick' handler -->
  <xsl:template match="Action" mode="button">
    <xsl:attribute name="onclick">window.location.href = '<xsl:value-of select="."/>'</xsl:attribute>
  </xsl:template>

  <!-- Event trigger -->
  <xsl:template match="Trigger" mode="button">
    <xsl:attribute name="data-command">trigger</xsl:attribute>
    <xsl:apply-templates select="@Target"/>
    <xsl:attribute name="data-trigger-event"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- ################### -->
  <!--   Generic widgets   -->
  <!-- ################### -->

  <!-- Ideally should be placed in Head ? -->
  <xsl:template match="DataIsland">
    <script id="{@Id}" type="application/xml" style="display:none">
      <xsl:copy-of select="*"/>
    </script>
  </xsl:template>

  <!-- ################ -->
  <!--   Radar widget   -->
  <!-- ################ -->
  
  <!-- Note: currently only supports @When="deferred" inside a Tab 
             loads radar on 'show' event on parent's Tab with an @Id
    -->
  <xsl:template match="Radar">
    <div data-command="ow-radar" class="cm-radar" data-event-type="show">
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:attribute name="data-event-target"><xsl:value-of select="ancestor::Tab/@Id"/></xsl:attribute>
    </div>
  </xsl:template>
</xsl:stylesheet>
