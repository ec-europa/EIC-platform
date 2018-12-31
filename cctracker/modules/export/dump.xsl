<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" media-type="text/csv" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="delim" select="';'" />
  <xsl:param name="quote" select="'&quot;'" />
  <xsl:param name="break" select="'&#xA;'" />

  <xsl:template match="/">
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="Cases">
    <xsl:apply-templates select="Case[1]" mode="headers"/>
    <xsl:apply-templates select="Case" />
  </xsl:template>

  <xsl:template match="error">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="Case" mode="headers">
    <xsl:apply-templates mode="headers"/>
    <xsl:if test="following-sibling::*">
      <xsl:value-of select="$break" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="headers">
    <xsl:value-of select="local-name(.)" />
    <xsl:if test="following-sibling::*">
      <xsl:value-of select="$delim" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="Case">
    <xsl:apply-templates />
    <xsl:if test="following-sibling::*">
      <xsl:value-of select="$break" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="*">
    <!-- remove normalize-space() if you want keep white-space at it is --> 
    <xsl:value-of select="concat($quote, normalize-space(), $quote)" />
    <xsl:if test="following-sibling::*">
      <xsl:value-of select="$delim" />
    </xsl:if>
  </xsl:template>

  <xsl:template match="text()" mode="headers"/>
  <xsl:template match="text()" />
</xsl:stylesheet>