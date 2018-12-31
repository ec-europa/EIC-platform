<?xml version="1.0" encoding="UTF-8" ?>

<!-- 

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Utility transformation to generates XTiger XML templates with extension points 
     for form fields. Takes as input an XML form grid specification as found 
     in the formulars folder. It generates a grid layout basd on Boostrap.

     NOTE: 
     - currently this transformation is EXPERIMENTAL and used at design to generate
     some of the templates foun din the templates folder
     - the generated template can be opened using AXEL demonstration editor, however 
     you will just be able to check the grid layout since the form fields by themselves 
     are extension points to be dynamically generated
     

     DEPRECATED: replaced by modules/formulars/supergrid.xsl which is using row-fluid

     July 2013 - European Union Public Licence EUPL
  -->


<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xt="http://ns.inria.org/xtiger" 
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml"
  >

  <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes" />

  <xsl:template match="/Form">
    <!-- <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html>
    </xsl:text> -->
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xt="http://ns.inria.org/xtiger" xmlns:site="http://oppidoc.com/oppidum/site" >
    <head><xsl:text>
    </xsl:text><xsl:comment>This template has been generated with "gridform.xsl"</xsl:comment><xsl:text>
    </xsl:text><meta http-equiv="content-type" content="text/html; charset=UTF-8" />

      <title><xsl:value-of select="Title"/></title>

      <!-- ******************************************** -->
      <!-- ********** BEGIN file system test ********** -->
      <!-- ******************************************** -->
      <!-- this is ONLY USEFUL to test the template with AXEL demonstration editor  -->
      <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap.css"/>
      <link rel="stylesheet" type="text/css" href="../resources/css/site.css"/>
      <!-- <link rel="stylesheet" type="text/css" href="../resources/css/activity.css"/> -->
      <!-- ******************************************** -->
      <!-- ********** END file system test ********** -->
      <!-- ******************************************** -->

      <xt:head version="1.1" templateVersion="1.0" label="{Form/RootTag}">
        <!-- Use this component as a main entry point to test this template inside the AXEL editor
             This component simulates application layout  -->
        <xt:component name="t_simulation">
          <div class="container">
            <form>
              <div id="editor">
                <xt:use types="t_main"/>
              </div>
            </form>
          </div>
        </xt:component>

        <!-- Use this component as the real entry point for this template  -->
        <xt:component name="t_main">
          <xsl:apply-templates select="Row"/>
        </xt:component>
      </xt:head>
    </head>
    <body>
      <xt:use types="t_main"/>
      <!-- <xt:use types="t_simulation"/> -->
    </body>
    </html>
  </xsl:template>
  
  <xsl:template match="Row">
    <div class="row">
      <xsl:apply-templates select="Field"/>
    </div>
  </xsl:template>
  
  <xsl:template match="Field">
    <div class="span{@Width}">
      <div class="control-group">
        <label class="control-label span{number(@Width) - number(@Size)}"><xsl:value-of select="."/></label>
        <div class="controls">
          <xsl:element name="site:{@Name}"><xsl:value-of select="@Tag"/></xsl:element>
        </div>
      </div>
    </div><xsl:comment>/span</xsl:comment>
  </xsl:template>
 
  <xsl:template match="Field[/Form/@Layout = 'vertical']">
    <div class="span{@Width}">
      <div class="control-group">
        <label class="control-label"><xsl:value-of select="."/></label>
        <div class="controls">
          <xsl:element name="site:{@Name}"><xsl:value-of select="@Tag"/></xsl:element>
        </div>
      </div>
    </div><xsl:comment>/span</xsl:comment>
  </xsl:template> 
</xsl:stylesheet>
