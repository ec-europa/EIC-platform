<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <xsl:param name="xslt.base-url">/</xsl:param>

  <xsl:include href="../../lib/commons.xsl"/>
  <xsl:include href="../../lib/widgets.xsl"/>
  <xsl:include href="../../lib/search.xsl"/>

  <xsl:template match="Patch">
    <h2><xsl:value-of select="upper-case(@Set)"/> Patch</h2>
    <pre>
      <xsl:copy-of select="*|text()"/>
    </pre>
  </xsl:template>
  
  <xsl:template match="Choose">
    <div id="editor" data-template="#">
      <h2>Choose the MS Excel file (.xslx) to import</h2>
      <p>
        <xt:use types="file" label="Test" param="file_URL=import;file_type=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;file_base=import;file_gen_name=auto;file_size_limit=2048;file_button_class=btn btn-primary"></xt:use>
      </p>
    </div>
    <xsl:if test="count(List/Unzipped)">
      <xsl:apply-templates select="List"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="List">
    <div id="editor2" data-template="#">
      <h2>Or please choose an existing unpackaged one amongst the following</h2>
      <ul>
        <xsl:for-each select="Unzipped">
          <xsl:variable name="loc"><xsl:value-of select="."/></xsl:variable>
          <li>
            <xsl:choose>
              <xsl:when test="@Deref">
                <a href="{$xslt.base-url}teams/import?validate={$loc}"><xsl:value-of select="."/></a>
              </xsl:when>
              <xsl:otherwise>
                <a href="{$xslt.base-url}teams/import?next={$loc}"><xsl:value-of select="."/></a>
              </xsl:otherwise>
            </xsl:choose>
          </li>
        </xsl:for-each>
      </ul>
    </div>
  </xsl:template>

  <!-- FIXME: use model to generate Assert button(s) actually hard-coded in this template rule -->
  <xsl:template match="Validate[not(child::error)]">
  <xsl:variable name="fn"><xsl:value-of select="@fn"/></xsl:variable>
  <h2>Call Import Wizard: Data Validation</h2>
    <xsl:apply-templates select="Confirm"/>
    <xsl:apply-templates select="//metadata"/>
    <h3>Please ensure that all data seem correct before import. Then assert new data against the database</h3>
    <p>The batch contains <xsl:value-of select="count(.//row)"/> rows : <a style="margin-bottom:10px" class="btn btn-primary" href="{$xslt.base-url}teams/import?assert={$fn}&amp;set=lear">Assert LEAR</a> <a style="margin-bottom:10px" class="btn btn-primary" href="{$xslt.base-url}teams/import?assert={$fn}&amp;set=pcoco">Assert PCOCO</a> <a style="margin-bottom:10px" class="btn btn-primary" href="{$xslt.base-url}teams/import?assert={$fn}&amp;set=signature">Assert Signature</a> </p>
    <div class="row-fluid">
      <div class="span6">
        <!-- <xsl:variable name="key"><xsl:value-of select="Mapping/Entry[@Key][@Set = 'lear']/Src/text()"/></xsl:variable>
        <xsl:variable name="pos"><xsl:value-of select="count(Mapping/Entry[@Key][@Set = 'lear']/preceding-sibling::*) + 1"/></xsl:variable> -->
        <!-- Not use since we mauy have multiple keys -->
        <xsl:variable name="pos">-1</xsl:variable>
        <table class="table table-bordered">
          <thead>
            <tr>
              <!-- <th><xsl:value-of select="$key"/></th> -->
              <xsl:for-each select="Mapping/Entry[position() != $pos]/Src">
                <th><xsl:value-of select="."/></th>
              </xsl:for-each>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="//rows/row">
              <tr>
                <!-- <td><xsl:value-of select="child::*[position() = $pos]"/></td> -->
                <xsl:for-each select="child::*[position() != $pos]">
                  <td>
                    <xsl:choose>
                      <xsl:when test="string-length(.) > 50"><xsl:value-of select="substring(.,0,50)"/> [...]</xsl:when>
                      <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
                    </xsl:choose>
                  </td>
                </xsl:for-each>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </div>
    </div>
  </xsl:template>
  
  <xsl:template match="metadata[not(*)]">
    <h3>Extracted Metadata</h3>
    <div class="row-fluid">
      <div class="span6">
        <table class="table table-bordered">
          <xsl:for-each select="*">
            <tr><td><xsl:value-of select="local-name(.)"/></td><td><xsl:value-of select="."/></td></tr>
          </xsl:for-each>
        </table>
      </div>
    </div>  
  </xsl:template>

  <xsl:template match="metadata[not(*)]">
    <h3>Extracted Metadata</h3>
    <div class="row-fluid">
      <div class="span12">
        <p>None</p>
      </div>
    </div>  
  </xsl:template>

  <xsl:template match="Confirm">
    <p>The XML file for batch import has already been validated. You can use the button to validate it again (this may take a few minutes if there are a few hundreds lines) or you can directly proceed with the assertion of data : <a style="margin-bottom:10px" class="btn btn-small" href="{$xslt.base-url}teams/import?validate={ancestor::Validate/@fn}&amp;_confirmed=1">Validate</a></p>
  </xsl:template>
  
  <xsl:template match="Assert">
    <xsl:variable name="fn"><xsl:value-of select="@fn"/></xsl:variable>
    <xsl:variable name="set"><xsl:value-of select="@Set"/></xsl:variable>
    <xsl:variable name="tagset"><xsl:value-of select="@Tag"/></xsl:variable>
    <xsl:variable name="total"><xsl:value-of select="count(//*[local-name() = $tagset])"/></xsl:variable>
    <h2>LEAR Import Wizard: Assert</h2>
    <div>
      <div class="row-fluid">
        <div class="span12">
          <h3><xsl:value-of select="$set"/> information is complete</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][not(.//MISSING)])"/> of <xsl:value-of select="$total"/>
            <xsl:if test="count(//*[local-name() = $tagset][not(.//MISSING)]) gt 0">
              <a style="margin-left: 15px" class="btn btn-primary" href="{$xslt.base-url}teams/import?run={$fn}&amp;set={@Set}">Import <xsl:value-of select="$tagset"/>s</a>
            </xsl:if>
          </p>
          <h3><xsl:value-of select="$set"/> personnal data is not complete</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][Information//MISSING])"/> of <xsl:value-of select="$total"/></p>
          <h3><xsl:value-of select="$set"/> Enterprise must be imported first into database</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][Projects//MISSING])"/> of <xsl:value-of select="$total"/></p>
          <xsl:call-template name="lears">
            <xsl:with-param name="lears" select="//*[local-name() = $tagset][Projects//MISSING]"/>
          </xsl:call-template>
        </div>
      </div>
    </div>
  </xsl:template>

  <!-- Factorize with Assert -->
  <xsl:template match="Assert[@Set eq 'signature']">
    <xsl:variable name="fn"><xsl:value-of select="@fn"/></xsl:variable>
    <xsl:variable name="set"><xsl:value-of select="@Set"/></xsl:variable>
    <xsl:variable name="tagset"><xsl:value-of select="@Tag"/></xsl:variable>
    <xsl:variable name="total"><xsl:value-of select="count(//*[local-name() = $tagset])"/></xsl:variable>
    <h2>LEAR Import Wizard: Assert</h2>
    <div>
      <div class="ecl-fieldset">
        <div class="span12">
          <h3><xsl:value-of select="$set"/> information is complete</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][not(.//MISSING)])"/> of <xsl:value-of select="$total"/>
            <xsl:if test="count(//*[local-name() = $tagset][not(.//MISSING)]) gt 0">
              <a style="margin-left: 15px" class="btn btn-primary" href="{$xslt.base-url}teams/import?run={$fn}&amp;set={@Set}">Import <xsl:value-of select="$tagset"/>s</a>
            </xsl:if>
          </p>
          <h3><xsl:value-of select="$set"/> date is not complete</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][.//MISSING[@Name eq 'Date']])"/> of <xsl:value-of select="$total"/></p>
          <h3><xsl:value-of select="$set"/> project must be imported first into database</h3>
          <p>Count : <xsl:value-of select="count(//*[local-name() = $tagset][.//MISSING[@Name eq 'Project']])"/> of <xsl:value-of select="$total"/></p>
        </div>
      </div>
    </div>
  </xsl:template>

  <xsl:template name="lears">
    <xsl:param name="lears"/>
    <ul>
      <xsl:for-each select="$lears">
        <li><xsl:value-of select="Information/Name/FirstName"/><xsl:text> </xsl:text><xsl:value-of select="Information/Name/LastName"/> (<xsl:value-of select="Information/Contacts/Email"/>) : <xsl:apply-templates select="Projects/Project[MISSING[starts-with(@Name, 'EnterpriseId')]]" mode="missing"/></li>
      </xsl:for-each>
    </ul>
  </xsl:template>

  <xsl:template match="Project" mode="missing">missing enterprise <xsl:value-of select="MISSING[starts-with(@Name, 'EnterpriseId')]"/> (project <xsl:value-of select="ProjectId"/>)<xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="Run">
    <h2>Call Import Wizard: Run</h2>
    <div>
      <div class="row-fluid">
        <h2>Results</h2>
        <xsl:apply-templates select="*"/>
      </div>
    </div>
  </xsl:template>

  <!-- generic feedback message -->
  <xsl:template match="done">
    <li><xsl:value-of select="@reason"/> in company <xsl:apply-templates select="Enterprises/EnterpriseRef"/></li>
  </xsl:template>

  <xsl:template match="same">
    <li>
      No need to update person <xsl:value-of select="Information/Name/LastName"/> with key <xsl:value-of select="@key"/> already in companie(s) : <xsl:apply-templates select="Enterprises/EnterpriseRef"/>
    </li>
  </xsl:template>
  
  <xsl:template match="same[Date]">
    <li>
      No need to update signature of Project <xsl:value-of select="@key"/> already in companie(s) : <xsl:apply-templates select="EnterpriseRef" mode="enterprises"/>
    </li>
  </xsl:template>

  <xsl:template match="created">
    <li>
      Created person <xsl:value-of select="Information/Name/LastName"/> with key <xsl:value-of select="@key"/> in companie(s) : <xsl:apply-templates select="Enterprises/EnterpriseRef"/>
    </li>
  </xsl:template>
  
  <xsl:template match="updated">
    <li>
      Updated person <xsl:value-of select="Information/Name/LastName"/> with key <xsl:value-of select="@key"/> in companie(s) : <xsl:apply-templates select="Enterprises/EnterpriseRef"/>
    </li>
  </xsl:template>

  <xsl:template match="updated[Date]">
    <li>
      Updated signature of Project <xsl:value-of select="@key"/> in companie(s) : <xsl:apply-templates select="EnterpriseRef" mode="enterprises"/>
    </li>
  </xsl:template>

  <xsl:template match="failed">
    <li>
      Failed with reason <xsl:value-of select="@reason"/> in companie(s) : <xsl:apply-templates select="Enterprises/EnterpriseRef"/>
    </li>
  </xsl:template>


  <xsl:template match="skipped">
    <li>
      Skipped because <xsl:value-of select="@reason"/> : <xsl:value-of select="."/>
    </li>
  </xsl:template>

  <xsl:template match="EnterpriseRef">
    <a href="{.}" target="_blank"><xsl:value-of select="."/></a><xsl:text>, </xsl:text>
  </xsl:template>

  <xsl:template match="EnterpriseRef[last()]">
    <a href="{.}" target="_blank"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="EnterpriseRef" mode="enterprises">
    <a href="../enterprises/{.}" target="_blank"><xsl:value-of select="."/></a><xsl:text>, </xsl:text>
  </xsl:template>

  <xsl:template match="EnterpriseRef[last()]" mode="enterprises">
    <a href="../enterprises/{.}" target="_blank"><xsl:value-of select="."/></a>
  </xsl:template>
  
  <xsl:template match="Invalidate">
    <li>
      Invalidate cache for <xsl:value-of select="."/>
    </li>
  </xsl:template>
  
  <xsl:template match="NoCache">
    <li>
      No cache for <xsl:value-of select="."/>
    </li>
  </xsl:template>

  <!-- TODO: move to commons.xsl ? -->
  <xsl:template match="error" priority="1">
    <h2>Oops !</h2>
  </xsl:template>

</xsl:stylesheet>
