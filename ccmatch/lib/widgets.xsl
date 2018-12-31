<?xml version="1.0" encoding="UTF-8"?>
<!-- CCMATCH - EIC Coach Match Application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Application User Interface rendering

     September 2015 - European Union Public Licence EUPL
  -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns:xt="http://ns.inria.org/xtiger"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>
  
  <!--<xsl:param name="xslt.base-url">/</xsl:param>-->
  
  <!-- =========== -->
  <!-- EXTENSIONS  -->
  <!-- =========== -->
  <xsl:include href="shared.xsl"/>
  <xsl:include href="../modules/suggest/suggest.xsl"/>
  <xsl:include href="../modules/management/management.xsl"/>




  <xsl:include href="../modules/coaches/acceptances.xsl"/>
  <xsl:include href="../modules/host/host.xsl"/>

  <!-- ****************************************** -->
  <!--                  TOP LEVEL                 -->
  <!-- ****************************************** -->

  <xsl:template match="Page">
    <site:view>
      <xsl:copy-of select="@skin"/>
      <xsl:apply-templates select="*"/>
    </site:view>
  </xsl:template>

  <xsl:template match="Overlay">
    <site:overlay>
      <xsl:apply-templates select="*"/>
    </site:overlay>
  </xsl:template>

  <!-- ****************************************** -->
  <!--               PAGE CONTENT                 -->
  <!-- ****************************************** -->

  <xsl:template match="Window">
    <site:title>
      <title><xsl:value-of select="."/></title>
    </site:title>
  </xsl:template>

  <xsl:template match="XTHead">
    <site:xt-head>
      <xsl:apply-templates select="Import"/>
    </site:xt-head>
  </xsl:template>
  
  <!-- Imports xt:component definitions from a mesh stored inside DB
    Rewrites component names to add a suffix to avoid component name 
    collisions when importing several files in a page
    FIXME: currently imports all xt:components (!) -->
  <xsl:template match="Import">
    <xsl:variable name="name"><xsl:value-of select="@Component"/></xsl:variable>
    <xsl:variable name="resource"><xsl:value-of select="concat(concat('xmldb:exist:///db/www/ccmatch/mesh/', @Mesh), '.xhtml')"/></xsl:variable>
    <xsl:apply-templates select="document($resource)//xt:component[(@name != 't_main') and (@name != 't_simulation')]" mode="import">
      <xsl:with-param name="suffix"><xsl:value-of select="@Suffix"/></xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="Acronym">
    <site:acronym>
      <span class="acronym"><xsl:value-of select="."/></span>
    </site:acronym>
  </xsl:template>

  <!-- FIXME: div redundancy with mesh to support command attribute -->
  <xsl:template match="Commands">
    <site:commands>
      <div>
        <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
        <xsl:apply-templates select="@* | *"/>
      </div>
    </site:commands>
  </xsl:template>

  <!-- ****************************************** -->
  <!--               PAGE CONTENT                 -->
  <!-- ****************************************** -->

  <xsl:template match="Content">
    <site:content>
      <div class="row-fuild" data-axel-base="{$xslt.base-url}">
        <xsl:apply-templates select="*"/>
      </div>
    </site:content>
  </xsl:template>

  <xsl:template match="Content[Tabs/TabBox]">
  
      <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="Verbatim">
    <xsl:apply-templates select="@* | *"/>
  </xsl:template>

  <xsl:template match="Views">
    <xsl:apply-templates select="@* | *"/>
  </xsl:template>

  <xsl:template match="View">
    <div>
      <xsl:apply-templates select="@* | *"/>
    </div>
  </xsl:template>

  <!--******************-->
  <!--*****  Tabs  *****-->
  <!--******************-->

  <!-- Plain version -->
  <xsl:template match="Tabs">
    <div class="tabbable tabs-left">
      <xsl:apply-templates select="@Id"/>
      <ul class="nav nav-tabs" style="width:120px">
        <xsl:apply-templates select="Tab" mode="nav"/>
      </ul>
      <div class="tab-content" data-axel-base="{$xslt.base-url}">
        <xsl:apply-templates select="Tab"/>
      </div>
    </div>
  </xsl:template>
  
  <!-- Version with TabBox / TabGroup -->
  <xsl:template match="Tabs[TabBox]">
    <site:tab-menu>
      <div class="well tabbable" style="width:170px;padding:0">
        <ul class="nav nav-list" style="width:140px;padding:15px">
          <xsl:apply-templates select="TabBox" mode="nav"/>
        </ul>
      </div>
    </site:tab-menu>
    <site:tab-content>
      <xsl:apply-templates select="TabBox"/>
    </site:tab-content>
  </xsl:template>

  <xsl:template match="TabBox" mode="nav">
    <xsl:apply-templates select="*" mode="nav"/>
  </xsl:template>
  
  <xsl:template match="TabGroup" mode="nav">
    <xsl:apply-templates select="Name" mode="tab"/>
    <xsl:apply-templates select="Tab" mode="nav"/>
  </xsl:template>

  <xsl:template match="Name" mode="tab">
    <li class="nav-header"><xsl:value-of select="."/></li>
  </xsl:template>

  <xsl:template match="Tab" mode="nav">
    <li>
      <xsl:if test="@State = 'invisible'">
        <xsl:attribute name="style">display:none</xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@TabId" mode="nav"/>
      <xsl:copy-of select="@class"/>
        <a href="#{@Id}" data-toggle="tab">
          <xsl:if test="ancestor::TabGroup">
            <xsl:attribute name="style">padding-left:40px</xsl:attribute>
          </xsl:if>
          <xsl:copy-of select="Name/@loc"/>
          <xsl:apply-templates select="Controller" mode="tab"/>
          <xsl:copy-of select="Name/* | Name/text()"/>
        </a>
    </li>
  </xsl:template>

  <!-- Deprecated hard-coded into mesh -->
  <xsl:template match="@TabId" mode="nav">
    <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="TabBox">
    <xsl:apply-templates select="Tab | TabGroup"/>
  </xsl:template>

  <xsl:template match="TabGroup">
    <xsl:apply-templates select="Tab"/>
  </xsl:template>

  <xsl:template match="Tab">
    <div id="{@Id}">
      <xsl:apply-templates select="@Command"/>
      <xsl:attribute name="class">tab-pane<xsl:if test="@class"><xsl:text> </xsl:text><xsl:value-of select="@class"/></xsl:if></xsl:attribute>
      <xsl:apply-templates select="@*[(local-name(.) != 'Id') and (local-name(.) != 'class')]"/>
      <xsl:apply-templates select="*[position() > 1]"/>
    </div>
  </xsl:template>
  
  <xsl:template match="Controller" mode="tab">
    <xsl:attribute name="data-src"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!--*******************-->
  <!--*** Collapsible ***-->
  <!--*******************-->

  <xsl:template match="Collapsible">
    <div style="float:right">
      <button id="{@Id}-control" type="button" class="btn btn-danger" data-toggle="collapse" data-target="#{@Id}">
        <xsl:apply-templates select="@State"/>
        <xsl:value-of select="Name/text()"/>
      </button>
    </div>
    <xsl:apply-templates select="Title"/>
    <div id="{@Id}" class="collapse">
      <xsl:apply-templates select="@*[(local-name(.) != 'Id') and (local-name(.) != 'State')]"/>
      <xsl:apply-templates select="*[(local-name(.) != 'Title') and (local-name(.) != 'Name')]"/>
    </div>
  </xsl:template>

  <!-- ##################################### -->

  <!--   Command buttons common attributes   -->
  <!-- ##################################### -->

  <!-- Confirmation popup dialog -->
  <xsl:template match="Confirm" mode="button">
    <xsl:attribute name="data-confirm"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- ############################################## -->
  <!--   Command buttons that can be placed anywhere  -->
  <!-- ############################################## -->

  <!-- Custom button (@Id most probably required to implement its behaviour in javascript) -->
  <xsl:template match="Button">
    <button>
      <xsl:attribute name="class">
        <xsl:choose>
          <xsl:when test="@class">btn <xsl:value-of select="@class"/></xsl:when>
          <xsl:otherwise>btn btn-primary</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>      
      <xsl:apply-templates select="@State"/>
      <xsl:apply-templates select="@Id"/>
      <xsl:apply-templates select="Action | Trigger" mode="button"/>
      <xsl:copy-of select="Label/@loc | @style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>
  
  <!-- FIXME: button initial state currently only 'disabled'-->
  <xsl:template match="@State[. = 'disabled']">
    <xsl:attribute name="disabled">disabled</xsl:attribute>
  </xsl:template>

  <!-- Cancel -->
  <xsl:template match="Cancel">
    <button class="btn btn-primary">
      <xsl:apply-templates select="Action" mode="button"/>
      <xsl:copy-of select="Label/@loc | @style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- ################################################################### -->
  <!--   Command buttons that must be placed in an editor (modal or not)   -->
  <!-- ################################################################### -->

  <!-- Save button acting on an implicit parent editor -->
  <xsl:template match="Save">
    <button class="btn btn-primary" data-command="save" data-target="{ancestor::Edit/@Id}">
      <xsl:if test="not(@data-save-flags)">
        <xsl:attribute name="data-save-flags">disableOnSave</xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="." mode="command"/>
      <xsl:apply-templates select="Resource" mode="edit"/>
      <xsl:apply-templates select="@Id"/>
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:copy-of select="Label/@loc | Label/@style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!--Save button acting on a remote explicit target editor 
      Copy cat of previous Save button -->
  <xsl:template match="Save[@Target]">
    <button class="btn btn-primary" data-target="{@Target}" data-save-flags="disableOnSave">
      <xsl:apply-templates select="." mode="command"/>
      <xsl:apply-templates select="@Id"/>
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:copy-of select="Label/@loc | Label/@style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>
  
  <!-- Plain save command -->
  <xsl:template match="Save" mode="command">
    <xsl:attribute name="data-command">save</xsl:attribute>
  </xsl:template>

  <!-- Save command with autoscroll when validation -->
  <xsl:template match="Save[@data-validation-output]" mode="command">
    <xsl:attribute name="data-command">save autoscroll</xsl:attribute>
  </xsl:template>
  
  <!-- Save command with TabControl sub-command -->
  <xsl:template match="Save[TabControl]" mode="command">
    <xsl:attribute name="data-command">save ow-tab-control</xsl:attribute>
    <xsl:apply-templates select="TabControl" mode="command"/>
  </xsl:template>
  
  <!-- Save command with autoscroll when validation and TabControl sub-command -->
  <xsl:template match="Save[@data-validation-output][TabControl]" mode="command">
    <xsl:attribute name="data-command">save autoscroll ow-tab-control</xsl:attribute>
    <xsl:apply-templates select="TabControl" mode="command"/>
  </xsl:template>
  
  <xsl:template match="TabControl">
    <button data-command="ow-tab-control">
      <xsl:call-template name="button-class"/>
      <xsl:apply-templates select="." mode="command"/>
      <xsl:copy-of select="Label/@loc | @style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- TODO: current version limited to one tab targets -->
  <xsl:template match="TabControl" mode="command">
    <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
    <xsl:apply-templates select="Disable" mode="inhibit"/>
    <xsl:apply-templates select="Select" mode="inhibit"/>
    <xsl:apply-templates select="Hide" mode="inhibit"/>
    <xsl:apply-templates select="ShowDelete" mode="inhibit"/>
  </xsl:template>
  
  <xsl:template match="Disable" mode="button">
    <xsl:attribute name="style">display: none;</xsl:attribute>
  </xsl:template>
  
  <xsl:template match="Disable|Select|Hide|ShowDelete" mode="inhibit">
    <xsl:attribute name="data-{translate(local-name(.), $uppercase, $smallcase)}-tab"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Disable[. = '']|Select[. = '']|Hide[. = '']|ShowDelete[. = '']" mode="inhibit">
    <xsl:attribute name="data-{translate(local-name(.), $uppercase, $smallcase)}-tab"><xsl:value-of select="ancestor::Tab/@Id"/></xsl:attribute>
  </xsl:template>

  <!-- Button to load an entity ('load' command) into editor's content -->
  <xsl:template match="Load">
    <button class="btn btn-primary" data-command="ow-load" data-target="{ancestor::Edit/@Id}">
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:copy-of select="Label/@loc | Label/@style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- Button to load an entity ('load' command) with editor's content
       Explicit @Target copy cat version of previous button -->
  <xsl:template match="Load[@Target]">
    <button class="btn btn-primary" data-command="ow-load" data-target="{@Target}">
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:copy-of select="Label/@loc | Label/@style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- Button to create an entity ('add' command) with @TargetEditor editor's content -->
  <xsl:template match="Create">
    <button data-command="add" data-src="{Controller}" data-edit-action="create" data-target="{@TargetEditor}" data-target-modal="{@TargetEditor}-modal" class="btn btn-primary btn-small">
      <xsl:copy-of select="Label/@loc | Label/@style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- Button to delete an entity ('ow-delete' command)
    -->
  <xsl:template match="Delete">
    <button data-command="ow-delete ow-inhibit">
      <xsl:call-template name="button-class"/>
      <xsl:if test="ancestor::Edit/@Id">
        <xsl:attribute name="data-target"><xsl:value-of select="ancestor::Edit/@Id"/></xsl:attribute>
      </xsl:if>
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:apply-templates select="Disable" mode="button"/>
      <xsl:apply-templates select="Confirm" mode="button"/>
      <xsl:copy-of select="Label/@loc | @style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- Button to generate a new password ('ow-password' command)
       MUST be placed inside a user account editor (very specific)
   -->
  <xsl:template match="Password">
    <button class="btn btn-primary" data-command="ow-password ow-inhibit" data-target="{ancestor::Edit/@Id}">
      <xsl:copy-of select="Label/@loc | @style"/>
      <xsl:value-of select="Label"/>
    </button>
  </xsl:template>

  <!-- ######################## -->
  <!--   Edit : inline editor   -->
  <!-- ######################## -->

  <!-- FIXME: create an 'edit' command -->
  <xsl:template match="Edit">
    <div class="row-fluid" data-axel-base="{$xslt.base-url}">
      <div class="span12">
        <xsl:apply-templates select="@Id"/>
        <xsl:apply-templates select="Resource" mode="edit"/>
        <xsl:apply-templates select="Template" mode="edit"/>
        <xsl:apply-templates select="*[local-name(.) != 'Resource'][local-name(.) != 'Template'][local-name(.) != 'Commands']"/>
        <xsl:if test="Template and not(Template/@When = 'inline')">
          <noscript loc="app.message.js">Activez Javascript</noscript>
          <p loc="app.message.loading" class="cm-busy">Form loading in progress</p>
        </xsl:if>
      </div>
    </div>
    <div class="row-fluid" style="margin-bottom: 20px">
      <xsl:if test="@Id">
        <div id="{@Id}-errors" class="alert alert-error af-validation">
          <button type="button" class="close" data-dismiss="alert">x</button>
        </div>
      </xsl:if>
      <xsl:apply-templates select="Commands" mode="edit"/>
    </div>
  </xsl:template>

  <!-- Classical menu placement (why 5 / 7) ? -->
  <xsl:template match="Commands" mode="edit">
    <div class="span5">
      <xsl:apply-templates select="Aside/*"/>
    </div>
    <div class="span7">
      <xsl:apply-templates select="*"/>
    </div>
  </xsl:template>
  
  <xsl:template match="Commands[@W]" mode="edit">
    <div class="span{@W}">
      <xsl:copy-of select="@style"/>
      <xsl:apply-templates select="*"/>
    </div>
  </xsl:template>

  <!-- TODO: merge with previous to support any @L -->
  <xsl:template match="Commands[@W][@L = '0']" priority="1" mode="edit">
    <div class="span{@W}">
      <xsl:choose>
        <xsl:when test="@style">
          <xsl:attribute name="style">margin-left:0;<xsl:value-of select="@style"/></xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="style">margin-left:0</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="*"/>
    </div>
  </xsl:template>

  <xsl:template match="Template" mode="edit">
    <xsl:attribute name="data-template"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="Template[@When = 'deferred']" mode="edit">
    <xsl:attribute name="data-template"><xsl:value-of select="."/></xsl:attribute>
    <xsl:attribute name="data-command">transform</xsl:attribute>
  </xsl:template>

  <xsl:template match="Template[@When = 'inline']" mode="edit">
    <xsl:attribute name="data-template">#</xsl:attribute>
    <xsl:attribute name="data-command">transform</xsl:attribute>
    <xt:use label="{@Tag}" types="{@TypeName}"/>
  </xsl:template>

  <xsl:template match="Resource" mode="edit">
    <xsl:attribute name="data-src"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- To avoid recursion -->
  <xsl:template match="Aside">
  </xsl:template>

  <!-- ################################################## -->
  <!--   Submit : inline editor with hidden form submit   -->
  <!-- ################################################## -->

  <xsl:template match="Submit">
    <div class="row-fluid">
      <div id="{@Id}" class="span12" data-template="{Template}" data-src="{Controller}">
        <noscript loc="app.message.js">Activez Javascript</noscript>
        <p loc="app.message.loading">Chargement du formulaire en cours</p>
      </div>
    </div>
    <div class="row-fluid" style="margin-bottom: 20px">
      <div class="span6">
        <button class="btn btn-primary" data-command="submit" data-target="{@Id}" data-form="{@Id}-form" style="float:right">Suggest</button>
      </div>
      <div class="span6">
        <xsl:apply-templates select="Commands/Cancel"/>
      </div>
      <form id="{@Id}-form" enctype="multipart/form-data" accept-charset="UTF-8"
        action="{@Action}" method="post" target="_blank" style="display:none">
        <input type="hidden" name="data"/>
      </form>
    </div>
  </xsl:template>

  <!-- ######### -->
  <!--    Menu   -->
  <!-- ######### -->
  
  <xsl:template match="Menu">
    <div>
      <xsl:attribute name="class">ow-menu <xsl:if test="@class"><xsl:text> active</xsl:text></xsl:if></xsl:attribute>
      <xsl:copy-of select="@*[starts-with(local-name(.), 'data-' )]"/>
      <xsl:apply-templates select="@Id | *"/>
    </div>
  </xsl:template>

  <xsl:template match="Menu[@Type = 'list']">
    <ul>
      <xsl:apply-templates select="Item"/>
    </ul>
  </xsl:template>

  <xsl:template match="Item">
    <li><xsl:apply-templates select="* | text()"/><xsl:apply-templates select="@Complete"/></li>
  </xsl:template>

  <xsl:template match="Item[@Link]">
    <li><a href="{@Link}"><xsl:value-of select="."/></a><xsl:apply-templates select="@Complete"/></li>
  </xsl:template>

  <xsl:template match="@Complete"><xsl:text> </xsl:text><span class="text-warn">(<xsl:value-of select="."/>% completed)</span>
  </xsl:template>

  <!-- ######### -->
  <!--   Title   -->
  <!-- ######### -->

  <xsl:template match="Title">
    <h2><xsl:copy-of select="@loc|@class|@style"/><xsl:apply-templates select="* |text()"/></h2>
  </xsl:template>

  <xsl:template match="Title[@Level]">
    <xsl:variable name="level"><xsl:value-of select="/*/@StartLevel + @Level - 1"/></xsl:variable>
    <xsl:element name="h{$level}">
      <xsl:copy-of select="@loc|@class|@style"/>
      <xsl:copy-of select="@style"/>
      <xsl:apply-templates select="@Id | * | text()"/>
    </xsl:element>
  </xsl:template>

  <!-- ######### -->
  <!--   Hint    -->
  <!-- ######### -->

  <xsl:template match="Hint">
    <span class="sg-hint" rel="tooltip" title="{.}"><xsl:copy-of select="@style | @data-placement"/><xsl:apply-templates select="@loc" mode="hint"/>?</span>
  </xsl:template>

  <xsl:template match="@loc" mode="hint">
    <xsl:attribute name="title-loc"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- ######### -->
  <!--    Text   -->
  <!-- ######### -->

  <xsl:template match="Text">
    <p><xsl:apply-templates select="@Id"/><xsl:copy-of select="@class | @loc | @style"/><xsl:apply-templates select="text() | *"/></p>
  </xsl:template>

  <!-- ########## -->
  <!--   Modals   -->
  <!-- ########## -->

  <xsl:template match="Modals">
    <div id="c-saving">
      <span class="c-saving" loc="term.saving">Enregistrement en cours...</span>
    </div>
    <xsl:apply-templates select="Show | Edit" mode="modal"/>
  </xsl:template>

  <!-- Modal window width
       FIXME: move px into Width to align with supergrid.xsl and workflow.xsl
  -->
  <xsl:template match="@Width" mode="modal">
    <xsl:attribute name="style">width:<xsl:value-of select="."/>px;margin-left:-<xsl:value-of select=". div 2"/>px</xsl:attribute>
  </xsl:template>

  <!-- Specific modal Edit window
       Save and Cancel currently mandatory
       Overwrites default Save and Cancel buttons logic
   -->
  <xsl:template match="Edit" mode="modal">
    <div id="{@Id}-modal" aria-hidden="true" aria-labelledby="label-{@Id}" role="dialog" tabindex="-1" class="modal hide fade" data-backdrop="static" data-keyboard="false">
      <xsl:apply-templates select="@Width" mode="modal"/>
      <div class="modal-header">
          <button aria-hidden="true" data-dismiss="modal" class="close" type="button">×</button>
          <h3 id="label-{@Id}"><xsl:value-of select="Name"/></h3>
      </div>
      <div class="modal-body" style="max-height:100%">
        <div id="{@Id}" data-command="transform" data-template="{Template}">
          <p loc="app.message.loading" class="cm-busy">Form loading in progress</p>
        </div>
      </div>
      <div class="modal-footer c-menu-scope">
        <div id="{@Id}-errors" class="alert alert-error af-validation">
          <button type="button" class="close" data-dismiss="alert">x</button>
        </div>
        <div style="float:left">
          <xsl:apply-templates select="Commands/Aside/*"/>
        </div>
        <xsl:apply-templates select="Commands/Delete"/>
        <xsl:choose>
          <xsl:when test="not(Commands/NoSave)">
            <button class="btn btn-primary" data-command="save ow-inhibit" data-target="{@Id}"
              data-type="json" data-replace-type="event" data-save-flags="silentErrors"
              data-validation-output="{@Id}-errors" data-validation-label="label">
              <xsl:copy-of select="Commands/Save/Label/@loc | Commands/Save/Label/@style"/>
              <xsl:value-of select="Commands/Save/Label"/>
            </button>
          </xsl:when>
        </xsl:choose>
        <button class="btn" data-command="trigger" data-target="{@Id}" data-trigger-event="axel-cancel-edit">
          <xsl:copy-of select="Commands/Cancel/Label/@loc | Commands/Save/Label/@style"/>
          <xsl:value-of select="Commands/Cancel/Label"/>
        </button>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="Show" mode="modal">
    <!-- Modal -->
    <div id="{@Id}" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="label-{@Id}" aria-hidden="true">
      <xsl:apply-templates select="@Width" mode="modal"/>
      <div style="position:absolute;top:0;right:10px;z-index:100">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
      </div>
      <div class="modal-body" style="max-height:100%">
      </div>
      <div class="modal-footer" style="height:30px">
        <button class="btn" data-dismiss="modal" aria-hidden="true" loc="action.close">Fermer</button>
      </div>
    </div>
  </xsl:template>

  <!-- ************************* -->
  <!--    xt:component import    -->
  <!-- ************************* -->
  
  <!-- TODO: get rid of site:field ? -->

  <!-- trick to avoid namespace prefix destruction  -->
  <xsl:template match="xt:use" mode="import">
    <xsl:param name="suffix"/>
    <xt:use>
      <xsl:copy-of select="@* | * | text()"/>
    </xt:use>
  </xsl:template>

  <xsl:template match="xt:use[starts-with(@types, 't_')]" mode="import">
    <xsl:param name="suffix"/>
    <xt:use types="{@types}_{$suffix}">
      <xsl:copy-of select="@*[local-name(.) != 'types'] | * | text()"/>
    </xt:use>
  </xsl:template>

  <!-- trick to avoid namespace prefix destruction  -->
  <xsl:template match="xt:repeat" mode="import">
    <xsl:param name="suffix"/>
    <xt:repeat>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="*" mode="import">
        <xsl:with-param name="suffix"><xsl:value-of select="$suffix"/></xsl:with-param>
      </xsl:apply-templates>  
    </xt:repeat>
  </xsl:template>

  <!-- trick to avoid namespace prefix destruction  -->
  <xsl:template match="xt:menu-marker" mode="import">
    <xsl:param name="suffix"/>
    <xt:menu-marker/>
  </xsl:template>

  <!-- trick to avoid namespace prefix destruction  -->
  <xsl:template match="xt:component" mode="import">
    <xsl:param name="suffix"/>
    <xt:component name="{@name}_{$suffix}">
      <xsl:copy-of select="@*[local-name(.) != 'name']"/>
      <xsl:apply-templates select="*" mode="import">
        <xsl:with-param name="suffix"><xsl:value-of select="$suffix"/></xsl:with-param>
      </xsl:apply-templates>  
    </xt:component>
  </xsl:template>

  <xsl:template match="*|@*|text()" mode="import">
    <xsl:param name="suffix"/>
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()" mode="import">
        <xsl:with-param name="suffix"><xsl:value-of select="$suffix"/></xsl:with-param>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>
  
  <!-- ########## -->
  <!--   Shared   -->
  <!-- ########## -->

  <xsl:template match="@Command">
    <xsl:attribute name="data-command"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <xsl:template match="*|@*|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
