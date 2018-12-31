# Coach Match Javascript Commands

## Invocation

### Client-side

Commands are usually triggered by user clicking the command host element (i.e. HTML DOM element holding the _data-command_ attribute).

### Server-side

Commands are triggered by returning an Ajax response containing a _forward_ element under the root element :

    <forward command="{command name}">{ command host element id }</forward>

This is currently not used in Coach Match

## List of commands

Commands are defined in widgets.js

### The 'ow-open' command

Mandatory attributes: `data-event-type`, `data-event-name`, `data-event-target`

Optional attribute: `data-open-link`

Instantiated in: modules/coaches/home.xql

This command is used to control a menu box in conjunction with the `ow-switch` command and to transform deferred templates.

Each time the tab control fires the *show* event, if there is no deferred template to transform or if the template has been successfully transformed it fires a `data-event-type` event with an event parameter (second event callback parameter) set to `data-event-name`. It triggers the event on the `data-event-target` node. This is a non bubbling event. This event is usually targeted at a node hosting an `ow-switch` command to change a menu box.

This command can be hosted on a tab pane content with a deferred XTiger template inside. It transforms the template when the associated tab fires the *show* event. The template is transformed only once (i.e. if it has not been transformed before).

The `data-open-link` if present replaces all the other behaviors and changes the window address to the address link it contains (directly setting `window.location.href`).

### The 'ow-switch' command

Mandatory attributes: `data-event-type`, `data-event-source`, `data-variable`

Satellite attributes: `data-meet-{:data-variable}`

Instantiated in: modules/coaches/home.xql

This command listens to a `data-event-type` on its `data-event-source` node. It must be hosted on a command box with several command menus. It then set the *active* class on the command menus hosting a `data-meet-{variable}` attribute set to the callback second parameter, with *variable* configured by the `data-variable` attribute.

Note the *ow-switch* command works with the *ow-open* command

### The 'ow-inhibit' command

### The 'ow-load' command

### The 'ow-isave' command

### The 'ow-autoscroll' command

### The 'ow-delete' command

### The 'ow-password' command


