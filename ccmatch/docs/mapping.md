# Coach Registration Process

Initial page :

1. GET /registration (registration.xql) 

    * brings up a tab view with two visible tabs (Help and Account Information) and one invisible tab (Login Information)

    * loads template GET /templates/coach/coach-registration?goal=create

2. 'save' command on Save button

    * POST /management/users <Profile> (modules/users/user.xql)

3. 'ow-tab-control' command (chained with 'save' command)

    * initializes Uuid in Account Information forms

    * upon 'save' success : 
    
      * disable tab Account Information

      * select tab Login Information

      * load template GET /templates/account?goal=create

      * load data GET /management/accounts/hash-string-XXX-YYY?goal=create (module/users/account.xql)

Then from Login Information :

1. 'save' command on Create Login button 
  
    * POST /management/accounts/hash-string-XXX-YYY?goal=create (module/users/account.xql)
    * redirects to login page on success
    
2. 'ow-tab-control' command on Change Account Information button

    * select tab Account Information
    * hide tab Login Information 
    * back to Initial page state

