<?xml version="1.0" encoding="UTF-8"?>

<!-- CCTRACKER - EIC Case Tracker Application

     Author: Frédéric Dumonceaux <fred.dumonceaux@gmail.com>

     Cases exportation facility

     April 2016 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:fo="http://www.w3.org/1999/XSL/Format">
    <xsl:attribute-set name="cells-head">
      <xsl:attribute name="border-collapse">collapse</xsl:attribute>
      <xsl:attribute name="border">1px solid #dddddd</xsl:attribute>
      <xsl:attribute name="background-color">#9ec0d9</xsl:attribute>
      <xsl:attribute name="border">1px solid #dddddd</xsl:attribute>
      <xsl:attribute name="padding">5px</xsl:attribute>
      <xsl:attribute name="text-align">center</xsl:attribute>
      <xsl:attribute name="font-weight">bold</xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="main-block">
      <xsl:attribute name="font-family">verdana</xsl:attribute>
      <xsl:attribute name="font-family">sans-serif</xsl:attribute>
      <xsl:attribute name="font-size">9pt</xsl:attribute>
      <xsl:attribute name="padding">10px</xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="other-block">
      <xsl:attribute name="padding">5px</xsl:attribute>
      <xsl:attribute name="text-align">left</xsl:attribute>
    </xsl:attribute-set>
    <xsl:attribute-set name="cells-right">
      <xsl:attribute name="border">1px solid #dddddd</xsl:attribute>
      <xsl:attribute name="padding">5px</xsl:attribute>
      <xsl:attribute name="text-align">left</xsl:attribute>
    </xsl:attribute-set>
    <xsl:template match="node() | @*">
      <xsl:copy>
        <xsl:apply-templates select="node() | @*"/>
      </xsl:copy>
    </xsl:template>
    <xsl:template match="fo:flow/fo:block">
      <xsl:copy use-attribute-sets="main-block">
        <xsl:apply-templates select="node() | @*"/>
      </xsl:copy>
    </xsl:template>
    <xsl:template match="fo:table[@id = 'summary']/fo:table-body/fo:table-row/fo:table-cell[1]
      | fo:table[@id = 'objectives']/fo:table-header/fo:table-row/fo:table-cell">
      <xsl:copy use-attribute-sets="cells-head">
        <xsl:apply-templates select="node() | @*"/>
      </xsl:copy>
    </xsl:template>
    <xsl:template match="fo:table[@id = 'activity']/fo:table-header/fo:table-row/fo:table-cell">
      <xsl:copy use-attribute-sets="cells-head">
        <xsl:apply-templates select="node() | @*"/>
      </xsl:copy>
    </xsl:template>
    <xsl:template match="fo:table-cell">
      <xsl:copy use-attribute-sets="cells-right">
        <xsl:apply-templates select="node() | @*"/>
      </xsl:copy>
    </xsl:template>
  <xsl:template match="fo:block[not( parent::fo:flow)] | fo:table[@id = 'objectives']/fo:table-body//fo:table-cell/fo:block">
      <xsl:copy use-attribute-sets="other-block">
        <xsl:apply-templates select="node() | @*"/>
      </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
