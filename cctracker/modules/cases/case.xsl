<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml">
  
  <xsl:template match="/">
    <xsl:apply-templates select="success | Case | Display"/>
  </xsl:template>
  
  <xsl:template match="success">
    <success>
      <xsl:copy-of select="message"/>
      <payload>
        <xsl:apply-templates select="payload/*"/>
      </payload>
    </success>
  </xsl:template>
  
  <!-- Intermediate element carrying @No to generate a correct Link when answering to Activity creation with POST  -->
  <xsl:template match="Display">
    <xsl:apply-templates select="Case"/>
  </xsl:template>
  
  <xsl:template match="Case">
    <tr>
      <xsl:if test="../@Current and No = string(../@Current)">
        <xsl:attribute name="class">current</xsl:attribute>
      </xsl:if>
      <td class="case"><xsl:apply-templates select="No"/></td>
      <td><xsl:if test="LinkedActivities/@Count > 1"><xsl:attribute name="rowspan"><xsl:value-of select="LinkedActivities/@Count"/></xsl:attribute></xsl:if><xsl:value-of select="Beneficiary"/></td>
      <td><xsl:if test="LinkedActivities/@Count > 1"><xsl:attribute name="rowspan"><xsl:value-of select="LinkedActivities/@Count"/></xsl:attribute></xsl:if><xsl:value-of select="ManagingEntity"/></td>
      <td><xsl:if test="LinkedActivities/@Count > 1"><xsl:attribute name="rowspan"><xsl:value-of select="LinkedActivities/@Count"/></xsl:attribute></xsl:if><xsl:value-of select="ResponsibleKAM"/></td>
      <td><xsl:if test="LinkedActivities/@Count > 1"><xsl:attribute name="rowspan"><xsl:value-of select="LinkedActivities/@Count"/></xsl:attribute></xsl:if><xsl:value-of select="CreationDate"/></td>
      <td><xsl:if test="LinkedActivities/@Count > 1"><xsl:attribute name="rowspan"><xsl:value-of select="LinkedActivities/@Count"/></xsl:attribute></xsl:if><xsl:value-of select="Status"/></td>
      <td><xsl:if test="LinkedActivities/No"><xsl:attribute name="class">activity</xsl:attribute></xsl:if><xsl:apply-templates select="LinkedActivities/No[1]"/></td>
    </tr>
    <xsl:for-each select="LinkedActivities/No[position() > 1]"><tr><td class="case"/><td class="activity"><xsl:apply-templates select="."/></td></tr></xsl:for-each>
  </xsl:template>
  
  <xsl:template match="No[parent::LinkedActivities]">
    <a href="{ancestor::Display/@ResourceNo}/cases/{ancestor::Case/No}/activities/{.}"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <!-- Rendering from a Case view -->
  <xsl:template match="No[parent::Case]">
    <a href="{ancestor::Display/@ResourceNo}/cases/{.}"><xsl:value-of select="."/></a>
  </xsl:template>
  
</xsl:stylesheet>
