<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="Console">
    <site:view>
      <xsl:apply-templates select="*"/>
    </site:view>
  </xsl:template>

  <xsl:template match="Title">
    <site:title>
      <title><xsl:value-of select="."/></title>
    </site:title>
  </xsl:template>

  <xsl:template match="Help">
    <site:help>
      <h2>Help</h2>
      <xsl:copy-of select="*"/>
    </site:help>
  </xsl:template>

  <xsl:template match="Output">
    <site:output>
      <h2>Output</h2>
      <xsl:copy-of select="*"/>
    </site:output>
  </xsl:template>

  <xsl:template match="Table">
    <site:table>
      <h2><xsl:value-of select="@Name"/></h2>
      <xsl:copy-of select="*"/>
    </site:table>
  </xsl:template>

</xsl:stylesheet>
