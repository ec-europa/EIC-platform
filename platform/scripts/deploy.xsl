<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
  <!ENTITY newline "&#xa;">
]>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="text"/>

  <xsl:template match="/">
SMEIMKT platform summary
<xsl:text>&newline;</xsl:text>
<xsl:apply-templates select="error | results/*"/>
  </xsl:template>

  <xsl:template match="error"><xsl:text>&newline;</xsl:text>
<xsl:value-of select="."/><xsl:text>&newline;&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="module">module : <xsl:value-of select="."/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="mode">mode : <xsl:value-of select="."/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="base">source : <xsl:value-of select="."/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="target"><xsl:text>&newline;</xsl:text>
<xsl:apply-templates select="*"/><xsl:text>&newline;</xsl:text>
</xsl:template>

  <xsl:template match="post">post actions :
<xsl:apply-templates select="*"/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="cleanup"><xsl:value-of select="."/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="help"><xsl:value-of select="."/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="newline"><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="ul"><xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="li"><xsl:text>&newline;</xsl:text>+ <xsl:value-of select="normalize-space(.)"/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <!-- FIXME: install DSL in Oppidum ? -->
  <xsl:template match="li[starts-with(., 'Uploaded')]"><xsl:text>&newline;</xsl:text>=> <xsl:value-of select="normalize-space(.)"/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <!-- FIXME: install DSL in Oppidum ? -->
  <xsl:template match="li[@style]"><xsl:text>&newline;</xsl:text>***ERROR*** <xsl:value-of select="normalize-space(.)"/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="p"><xsl:value-of select="normalize-space(.)"/><xsl:text>&newline;</xsl:text>
  </xsl:template>

  <xsl:template match="*">
  </xsl:template>

</xsl:stylesheet>
