<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:template match="/">
    <div id="results">
      <xsl:apply-templates select="Histories"/>
    </div>
  </xsl:template>

  <xsl:template match="Histories">
    <h2>Displaying digests from the last <xsl:value-of select="@Max"/> days in each category</h2>
    <xsl:apply-templates select="Category"/>
  </xsl:template>

  <xsl:template match="Histories[not(Category)]">
    <p>No category recorded</p>
    <p class="text-warn">Check nighlty jobs configuration in <i>conf.xml</i></p>
  </xsl:template>

  <xsl:template match="Category">
    <h3>Category <i><xsl:value-of select="@Name"/></i></h3>
    <xsl:apply-templates select="Digest"/>
  </xsl:template>

  <xsl:template match="Digest">
    <p><xsl:call-template name="date"/> at <xsl:value-of select="substring(@Timestamp, 12, 5)"/><xsl:text> </xsl:text><xsl:apply-templates select="." mode="count"/></p>
  </xsl:template>

  <xsl:template match="Digest" mode="count"><span style="color:blue"><xsl:value-of select="count(Entry)"/> entry</span>
  </xsl:template>

  <xsl:template match="Digest[count(Entry) > 1]" mode="count"><span style="color:blue"><xsl:value-of select="count(Entry)"/> entries</span>
  </xsl:template>

  <xsl:template match="Digest[not(Entry) and not(error)]" priority="1">
    <p><xsl:call-template name="date"/> at <xsl:value-of select="substring(@Timestamp, 12, 5)"/><xsl:text> </xsl:text><i>no entry</i></p>
  </xsl:template>

  <xsl:template match="Digest[error or Entry/error]" priority="1">
    <xsl:variable name="err-nb"><xsl:value-of select="count(error) + count(Entry/error)"/></xsl:variable>
    <p><xsl:call-template name="date"/> at <xsl:value-of select="substring(@Timestamp, 12, 5)"/><xsl:text> </xsl:text><xsl:apply-templates select="." mode="count"/><xsl:text> with </xsl:text><span style="color:red"><xsl:value-of select="$err-nb"/> error<xsl:if test="$err-nb > 1">s</xsl:if></span></p>
    <blockquote>
        <xsl:apply-templates select="error | Entry/error"/>
    </blockquote>
  </xsl:template>

  <xsl:template match="error[@object]" priority="1">
    <p><xsl:value-of select="."/> : <xsl:value-of select="@object"/></p>
  </xsl:template>

  <xsl:template match="error[message]">
    <p><xsl:value-of select="message/@type"/> : <xsl:value-of select="message"/></p>
  </xsl:template>

  <!-- exception -->
  <xsl:template match="error[not(message)]">
    <p>EXCEPTION : <xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template name="date">
    <xsl:value-of select="substring(@Timestamp, 9, 2)"/>/<xsl:value-of select="substring(@Timestamp, 6, 2)"/>/<xsl:value-of select="substring(@Timestamp, 1, 4)"/>
  </xsl:template>
  
</xsl:stylesheet>
