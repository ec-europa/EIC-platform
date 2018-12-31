<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="application/xhtml+xml" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <!-- Returns a static view of the application parameters -->
  <xsl:template match="/Params[@Goal = 'read']">
    <div id="results" class="row-fluid">
      <h2>Application parameters</h2>
      <form>
        <div class="row-fluid">
          <xsl:apply-templates select="Field"/>
        </div>
      </form>
      <p style="margin-top: 20px">
        <button class="btn btn-primary" onclick="javascript:$(event.target).trigger('coaching-update-params')">Modifier</button>
      </p>
    </div>
  </xsl:template>

  <!-- Returns an XTiger XML template to edit application parameters
       NB: we could have used Supergrid instead but this avoids to map an extra formular  -->
  <xsl:template match="/Params[@Goal = 'update']">
    <html xmlns:xt="http://ns.inria.org/xtiger">
      <head>
        <xt:head label="Params"/>
      </head>
      <body>
        <form>
          <div class="row-fluid">
            <xsl:apply-templates select="Field" mode="update"/>
          </div>
        </form>
      </body>
    </html>
  </xsl:template>

  <!-- Returns a READONLY field  -->
  <xsl:template match="Field">
    <div class="span12" style="margin-left:0">
        <div class="control-group">
            <label class="control-label"><xsl:value-of select="@Label"/></label>
            <div class="controls">
              <span class="uneditable-input span a-control" label="{@Tag}"><xsl:value-of select="."/></span>
            </div>
        </div>
    </div>
  </xsl:template>

  <!-- Returns a WRITABLE field  -->
  <xsl:template match="Field" mode="update">
    <div class="span12" style="margin-left:0">
      <div class="control-group">
          <label class="control-label"><xsl:value-of select="@Label"/></label>
          <div class="controls">
            <xt:use types="input" param="class=span a-control;" label="{@Tag}"><xsl:value-of select="."/></xt:use>
          </div>
      </div>
    </div>
  </xsl:template>

</xsl:stylesheet>
