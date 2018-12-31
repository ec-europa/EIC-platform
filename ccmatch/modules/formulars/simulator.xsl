<?xml version="1.0" encoding="UTF-8"?>
<!-- Oppidoc Supergrid application

     Author: Stéphane Sire <s.sire@opppidoc.fr>

     Form generator basic user interface for developpers

     September 2015 - European Union Public Licence EUPL
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:site="http://oppidoc.com/oppidum/site"
  xmlns="http://www.w3.org/1999/xhtml">

  <xsl:output method="xml" media-type="text/html" omit-xml-declaration="yes" indent="yes"/>

  <!-- Parameters (can be set on command line) -->
  <xsl:param name="xslt.base-url">resources/</xsl:param>
  <xsl:param name="xslt.lang">fr</xsl:param>
  <xsl:param name="xslt.rights"></xsl:param>

  <xsl:template match="/">
    <site:view>
      <site:content>
        <h1 class="noprint">Genérateur de formulaires</h1>
        <form class="noprint" style="background-color:#F7E9D4;margin-bottom:2em" action="" onsubmit="return false;">
          <div class="row-fluid">
              <div class="span8">
                <div class="control-group">
                  <label class="control-label a-gap2">Choix du formulaire</label>
                  <div class="controls">
                    <xsl:apply-templates select="Formulars"/>
                    <button id="x-test" class="btn btn-primary">Tester</button>
                    <button id="x-control" class="btn">Contrôler</button>
                    <button id="x-dump" class="btn">Dump</button>
                  </div>
                </div>
              </div>
              <!-- TO BE REWRITTEN (FIREFOX no more supports view-source protocol)
                <div class="span4">
                  <div style="float:right">
                    <button id="x-src" class="btn btn-warning">Source</button>
                    <button id="x-generate" class="btn btn-warning">Générer</button>
                    <button id="x-model" class="btn btn-warning">Modèle</button>
                  </div>
                </div> -->
          </div>
          <div class="row-fluid">
              <div class="span5">
                <div class="control-group">
                  <label class="control-label a-gap2">Version en ligne</label>
                  <div class="controls">
                    <button id="x-display" class="btn">Voir</button>
                    <button id="x-validate" class="btn">Valider</button>
                    <xsl:if test="$xslt.rights = 'install'">
                      <button id="x-install" class="btn btn-small btn-primary">Installer</button>
                    </xsl:if>
                  </div>
                </div>
              </div>
              <div class="span3">
                <div class="control-group">
                  <label class="control-label a-gap1">Mode</label>
                  <div class="controls">
                    <select id="x-mode">
                      <option value="read">read</option>
                      <option value="create">create</option>
                      <option value="update">update</option>
                    </select>
                  </div>
                </div>
              </div>
              <xsl:if test="$xslt.rights = 'install'">
                <div class="span4">
                  <div style="float:right">
                    <button id="x-install-all" class="btn btn-danger">Tout installer</button>
                  </div>
                </div>
              </xsl:if>
          </div>
        </form>
        <div id="c-editor-errors" class="alert alert-error af-validation">
          <button type="button" class="close" data-dismiss="alert">x</button>
        </div>
        <div id="x-simulator" class="c-editing-mode">
          <noscript>Activez Javascript</noscript>
          <p>Zone de simulation du formulaire</p>
        </div>
        <div class="noprint">
          <h2 style="text-align:left">Notes</h2>
          <p>Cette page permet de tester les formulaires dont les spécifications figurent dans le répertoire <tt>formulars</tt>. Vous pouvez également utiliser le bouton <i>Générer</i> pour générer le formulaire et le copier-coller dans son fichier source correspondant dans le répertoire <tt>templates</tt>.</p>
          <ul>
          <li>les champs de saisie (bouton <i>Tester</i>) sont seulement simulés, ils seront remplacés par leur version définitive dans le formulaire en situation en faisant appel au script conventionnellement nommé <tt>form.xql</tt></li>
          <li>utilisez le bouton <i>Contrôler</i> pour afficher les clefs des champs, le label XML dans le modèle cible et la largeur du Gap; les clefs des champs doivent se retrouver sur un élément <code>&lt;site:field Key="clef"></code> dans le fichier <tt>form.xql</tt> correspondant au formulaire, un Gap de 0 sur un champ simple (Field) signifie que le label est affiché au dessus du champ</li>
          <li>pour utiliser le bouton <i>Dump</i> vous devez au préalable afficher le formulaire avec le bouton <i>Tester</i>, il donne un aperçu du modèle XML du formulaire</li>
          </ul>
        </div>
      </site:content>
    </site:view>
  </xsl:template>

  <xsl:template match="Formulars">
    <select id="x-formular">
      <xsl:apply-templates select="Formular"/>
    </select>
  </xsl:template>

  <xsl:template match="Formular">
    <option value="{Form}"><xsl:value-of select="Name"/></option>
  </xsl:template>

  <xsl:template match="Formular[Template]">
    <option data-display="{Template}" value="{Form}"><xsl:value-of select="Name"/></option>
  </xsl:template>
</xsl:stylesheet>
