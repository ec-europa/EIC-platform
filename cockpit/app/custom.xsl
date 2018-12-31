<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site" 
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:template match="Home">
    <a href="{.}" style="text-decoration:none"><img id="logo" src="{ $xslt.base-url }static/cockpit/images/home.png"/></a> <a href="{.}">Home</a>
  </xsl:template>

</xsl:stylesheet>
