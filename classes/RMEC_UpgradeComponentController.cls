/************************************************************************************************************************************************************
    Name:           RMEC_UpgradeComponentController 
    Description:    This class is used to upgrade plan for Splunk Cloud purchase
    Author:         Accenture
    
    Date                PRJ/DFCT/ENHC#          Summary of Changes 
    ---------------     ------------------      ------------------------------
    03 Sept 2015        RainMakr MVP2           Initial Release     
    30 March 2016       RainMakr Balderdash     BIZ-1490 - POC
*************************************************************************************************************************************************************/
public class RMEC_UpgradeComponentController{
    public RMEC_Content_Management_Setting__c contentMapping{get;set;}
    private String prdType;
    private String instId;
    public String existingSize {get;set;}
    public String existingPlan {get;set;}
    private List<Integer> recommendedSizeList;
    public String recommendedSize {get;set;}
    public String recommendedSizeForTrial {get;set;}
    public String existingSizeForTrial {get; set;}
    public String selectedSize {get;set;}
    public ProductWrapper prodWrapObj {get;set;}
    public Boolean isdisabled{get;set;}
    public list<ProductWrapper> pMonthly{get;set;}
    public list<ProductWrapper> pAnually{get;set;}
    private String contactId;
    private Map<String,ProductWrapper> prodMap;   
    private string region;
    private Shopping_Cart__c shopCart = new Shopping_Cart__c();
    private Cloud_Stack__c cldInst =  new Cloud_Stack__c();
    private List<Shopping_Cart_Item__c> shopCartItemList = new List<Shopping_Cart_Item__c>();
    private List<String> sizeProdList;
    public String planHeader {get;set;}
    public String planHeaderText1 {get;set;}
    public String planHeaderText2 {get;set;}
    public String navBarLeftSect {get;set;}
    public String navBarMiddleSect {get;set;}
    public String buttonText {get;set;}
    public String prodType {get;set;}
    public String planSectionText1 {get;set;}
    public String planSectionText2 {get;set;}
    public String planSectionText3 {get;set;}
    public String planSectionText4 {get;set;}
    public String planSectionURL1 {get;set;}
    public String planSectionURL2 {get;set;}
    public String planSectionURL3 {get;set;}
    public String planSectionURLText1 {get;set;}
    public String planSectionURLText2 {get;set;}
    public String planSectionURLText3 {get;set;}
    private String temp;
    private String productInstance;
    private string tempsize;
    private Integer maxvalue;
    public boolean contactSales{get;set;}
    public String contactSalesMessage{get;set;}
    public String ipAddress;
    @TestVisible Transient HttpResponse geoIpHttpResponse;
    @TestVisible RMEC_GeoIpResponseParser resObj;
    /****************************************************************************************************************************************************
        * Name: RMEC_UpgradeComponentController
        * Description: Controller Class
    *****************************************************************************************************************************************************/ 
    public RMEC_UpgradeComponentController(){
    sizeProdList=new List<String>();
    pMonthly=new List<ProductWrapper>();
    prodMap=new Map<String,ProductWrapper>();
    pAnually=new List<ProductWrapper>();
    recommendedSizeList=new List<Integer>();
    sizeProdList=new List<String>();
    
    contentMapping=new RMEC_Content_Management_Setting__c();
        instId = ApexPages.currentPage().getParameters().get(System.Label.RMEC_INID);
        if(instId != null){
            cldInst = [Select Size_GB__c, Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c, Fulfillment_Case__r.Subscription_Payment__r.Subscription_End_Date__c, Fulfillment_Case__r.Subscription_Payment__r.Subscription_Start_Date__c, Product_Type__c, InstanceType__c,End_Date__c, Start_Date__c from Cloud_Stack__c where Id =: instId];

        }
        /*  change the type of fetching the prdtype = SplunkCloudUpgarde */ 
        if(cldInst.Product_Type__c != null)
        {   
            temp = cldInst.Product_Type__c.deleteWhiteSpace();            
            productInstance= temp+System.Label.UPGRADE;
        }
        contentMapping = RMEC_Content_Management_Setting__c.getValues(productInstance);
        /*******ends here******/
        planHeader = contentMapping.Plan_Section_Header__c;
        planHeaderText1 = contentMapping.Plan_Section_Header_Text_1__c;
        planHeaderText2 = contentMapping.Plan_Section_Header_Text_2__c;
        navBarLeftSect = contentMapping.Nav_Bar_Section_1__c;
        navBarMiddleSect = contentMapping.Nav_Bar_Section_2__c;
        buttonText = contentMapping.Prod_Page_Button_Text__c;
        prodType = contentMapping.Product_Name_Display__c;
        planSectionText1 = contentMapping.Plan_Section_Text_1__c;
        planSectionText2 = contentMapping.Plan_Section_Text_2__c;
        planSectionText3 = contentMapping.Plan_Section_Text_3__c;
        planSectionText4 = contentMapping.Plan_Section_Text_4__c;
        planSectionURL1 = contentMapping.Plan_Section_Text_URL_1__c;
        planSectionURL2 = contentMapping.Plan_Section_Text_URL_2__c;
        planSectionURL3 = contentMapping.Plan_Section_Text_URL_3__c;
        planSectionURLText1 = contentMapping.Plan_Section_Text_URL_Text_1__c;
        planSectionURLText2 = contentMapping.Plan_Section_Text_URL_Text_2__c;
        planSectionURLText3 = contentMapping.Plan_Section_Text_URL_Text_3__c;
        prodWrapObj = new ProductWrapper();
        isdisabled = true;
        ipAddress = EC_Constants.BLANK;
        pMonthly = new list<ProductWrapper>();
        pAnually = new list<ProductWrapper>();
        prodMap = new Map<String,ProductWrapper>();
        recommendedSizeList = new List<Integer>();
        User loggedInUser = [select Id,ContactId, Contact.Geo__c, Contact.Region__c,Contact.MailingCity,Contact.MailingState, Contact.MailingCountry,CP_Lead_Id__c from User where Id =: UserInfo.getUserId() Limit 1];
        List<Shopping_Cart__c> scL = new List<Shopping_Cart__c>();
        if(loggedinUser.ContactId != null){
            scL = [select Id,Contact__c,Total_Size__c,Name from Shopping_Cart__c where Contact__c=:loggedInUser.ContactId LIMIT 1];
        }
        if(!scL.isEmpty()) {
            shopCart = scL[0];
        }
        if(shopCart != null && shopCart.id != null) {
            shopCartItemList = [select Id,Product__r.License_Template__c,Subscription_Duration__c,Region__c,Sub_Total__c,Total_Amount__c,Product__r.Ava_TaxCode__c, Price_Book__r.Name,is_Product_Size_Editable__c,Product_Type__c,Selected_Size__c,Price_Book__c,Product__r.ProductCode,Product__r.Item_Category__c,Quantity__c,Purchase_Type__c,Product_Size__c,Product__c,Name,Status__c,Product__r.NoQuotaEnforcement_Template__c from Shopping_Cart_Item__c where Shopping_Cart__r.Id =: shopCart.Id AND  Status__c=: EC_Constants.IN_CART AND RecordTypeId =: Label.RMEC_eCOMMERCE_RECORD_TYPE_ID];
        } 
        if(!shopCartItemList.isEmpty()){
            isdisabled = false;
            region = shopCartItemList[0].Region__c;
            if(cldInst.InstanceType__c != null && (cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL) || (cldInst.Size_GB__c != null && cldInst.Size_GB__c < shopCartItemList[0].Product_Size__c))){
                selectedSize = shopCartItemList[0].Subscription_Duration__c+RMEC_Constants.DASH+String.valueOf(shopCartItemList[0].Product_Size__c)+EC_Constants.GB;
            }
        }
        if(cldInst.InstanceType__c != null && cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL)){
            existingSize = RMEC_Constants.ANNUALLY+RMEC_Constants.DASH+0+EC_Constants.GB;
            existingSizeForTrial = RMEC_Constants.MONTHLY+RMEC_Constants.DASH+0+EC_Constants.GB;
        }
        else{
            if(!Test.isRunningTest()){
                if(cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c != null && cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c.equalsIgnoreCase(RMEC_Constants.MONTHLY) ){      
                    existingPlan = cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c;
                    existingSize = cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c+RMEC_Constants.DASH+cldInst.Size_GB__c+EC_Constants.GB;
                }
                else if(cldInst.InstanceType__c.equalsIgnoreCase(Label.CLOUDSTACK_INSTANCE_TYPE_POC)){
                    existingSize = RMEC_Constants.MONTHLY+RMEC_Constants.DASH+cldInst.Size_GB__c+EC_Constants.GB;
                } // BIZ-1490
                else{
                    existingPlan = RMEC_Constants.ANNUALLY;
                    existingSize = RMEC_Constants.ANNUALLY+RMEC_Constants.DASH+cldInst.Size_GB__c+EC_Constants.GB;
                }
            }
            else{
                existingPlan = RMEC_Constants.ANNUALLY;
                existingSize = RMEC_Constants.ANNUALLY+RMEC_Constants.DASH+cldInst.Size_GB__c+EC_Constants.GB;
            }
        }
        if(existingPlan != null && !shopCartItemList.isEmpty() && shopCartItemList[0].Subscription_Duration__c != null && existingPlan != shopCartItemList[0].Subscription_Duration__c){
            selectedSize = EC_CONSTANTS.BLANK;
        }
        contactId = loggedInUser.ContactId;
        region = loggedInUser.Contact.Geo__c;

        if(region == null){
            if(System.Label.RMEC_GeoIP_Test.equalsIgnoreCase(RMEC_Constants.IPTEST)) {
                ipAddress = apexpages.currentpage().getheaders().get(system.label.RMEC_True_Client_IP);
            }
            else {
                ipAddress = System.Label.RMEC_GeoIP_Test;
            } 
            setRegion();
        }
        else{
            region = RMEC_Utility.checkRegion(loggedInUser.Contact.Geo__c,loggedInUser.Contact.Region__c,loggedInUser.Contact.MailingCountry)[0];
            if(region == null){
                contactSales=true;
                contactSalesMessage = Label.RMEC_CONTACT_SALES_MSG_1+RMEC_Constants.CONTACT_SALES_MSG1;
            }
        }
        Date tdate;
        Date actualEndDate;
        integer tdays;
        integer daysleft;
        if(cldInst.InstanceType__c != null && !cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL) && !cldInst.InstanceType__c.equalsIgnoreCase(Label.CLOUDSTACK_INSTANCE_TYPE_POC)){ // BIZ-1490
            tdate = System.today();
            actualEndDate = cldInst.Fulfillment_Case__r.Subscription_Payment__r.Subscription_End_Date__c;
            tdays = cldInst.Fulfillment_Case__r.Subscription_Payment__r.Subscription_Start_Date__c.daysBetween(actualEndDate);
            daysleft = tdate.daysBetween(actualEndDate);
        }
        else{
            tdate = System.today();
            actualEndDate = cldInst.End_Date__c;
            tdays = cldInst.Start_Date__c.daysBetween(actualEndDate);
            daysleft = tdate.daysBetween(actualEndDate);
        }
        List<Integer> sortedProductSize =  new List<Integer>();
        List<String> productSizes = contentMapping.Available_Sizes__c.split(EC_CONSTANTS.SEMICOLON);
        if(productSizes.size() > 0){ 
            for(String pSize : productSizes)
            {
                sortedProductSize.add(integer.valueof(pSize));
            }
            sortedProductSize.sort();

            maxvalue = sortedProductSize.get(0);        
            //maxvalue = integer.valueof(productSizes[0]);
            for (integer i =0;i<productSizes.size();i++){
                if( integer.valueof(productSizes[i]) > maxvalue)
                maxvalue = integer.valueof(productSizes[i]);             
            }           
            if(String.valueOf(maxvalue) == String.valueOf(cldInst.Size_GB__c)){
                contactSales=true;
                contactSalesMessage= RMEC_Constants.CONTACT_SALES_MSG2;
            }
            for(String pS:productSizes){
                if(integer.valueOf(pS) > cldInst.Size_GB__c){
                    recommendedSizeList.add(integer.valueOf(pS));
                }
                else if(cldInst.Size_GB__c == null && integer.valueOf(pS) != 0){
                    recommendedSizeList.add(integer.valueOf(pS));
                }
                if(ps.equalsIgnoreCase(System.Label.RMEC_NUMBER_ZERO)){
                    pMonthly.add(new ProductWrapper(contentMapping.Product_Code__c,ps,0.0,RMEC_Constants.MONTHLY,false,0.0,true,contentMapping.Trial_Product__c,Integer.valueOf(contentMapping.trialTotalGBStorage__c)));
                    pAnually.add(new ProductWrapper(contentMapping.Product_Code__c,ps,0.0,RMEC_Constants.ANNUALLY,false,0.0,true,contentMapping.Trial_Product__c,Integer.valueOf(contentMapping.trialTotalGBStorage__c)));
                    prodMap.put(RMEC_Constants.MONTHLY+RMEC_Constants.DASH+ps+EC_Constants.GB,new ProductWrapper(contentMapping.Product_Code__c,pS,0.0,RMEC_Constants.MONTHLY,false,0.0,true,contentMapping.Trial_Product__c,Integer.valueOf(contentMapping.trialTotalGBStorage__c)));
                    prodMap.put(RMEC_Constants.ANNUALLY+RMEC_Constants.DASH+ps+EC_Constants.GB,new ProductWrapper(contentMapping.Product_Code__c,pS,0.0,RMEC_Constants.ANNUALLY,false,0.0,true,contentMapping.Trial_Product__c,Integer.valueOf(contentMapping.trialTotalGBStorage__c)));
                }
                else{
                    Functionality_Enable_Disable__c fRec = Functionality_Enable_Disable__c.getValues(System.Label.RAIN_MAKR_LOWERPRICE);
                    for(RMEC_Product_Size_Mapping__c productSizeRec: RMEC_Product_Size_Mapping__c.getall().values()){     
                        if(productSizeRec.Product_Code__c.equalsIgnoreCase(contentMapping.Product_Code__c)){    
                            if((integer.valueOf(pS) <= productSizeRec.End_License_Size__c) && (integer.valueOf(pS) >= productSizeRec.Start_License_Size__c) && (productSizeRec.Duration__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)) && (productSizeRec.Region__c.equalsIgnoreCase(region)) && (productSizeRec.Active__c == true)){
                                Decimal tempProRatedPrice;                              
                                Decimal perGbPrice = productSizeRec.Price__c;
                                if(fRec != null && fRec.Enable__c){
                                    perGbPrice = productSizeRec.Price__c/100;
                                }
                                if(cldInst.Size_GB__c != null && !cldInst.InstanceType__c.equalsIgnoreCase(Label.CLOUDSTACK_INSTANCE_TYPE_POC)){ // BIZ-1490
                                    if(tdays == 0)
                                    {
                                        tempProRatedPrice = 0;
                                    }
                                    else
                                    {
                                        tempProRatedPrice = (integer.valueOf(pS) - cldInst.Size_GB__c)* perGbPrice * daysleft/tdays;
                                    }   
                                }
                                else{
                                    tempProRatedPrice = integer.valueOf(pS) * perGbPrice;
                                }                               
                /* BIZ-1490 */
                                Boolean isactive = false;
                                if(cldInst.InstanceType__c.equalsIgnoreCase(Label.RMBD_INSTTYPEPOC)){
                                    if(integer.valueOf(pS) >= cldInst.Size_GB__c){
                                        isactive = true;
                                    }
                                }else if(cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_PAID)){
                                    if(integer.valueOf(pS) > cldInst.Size_GB__c){
                                        isactive = true;
                                    }
                                }
                                else{
                                    isactive = true;
                                }
                                if(productSizeRec.Duration__c.equalsIgnoreCase(existingPlan)){
                                    pMonthly.add(new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                    prodMap.put(productSizeRec.Duration__c+RMEC_Constants.DASH+ps+EC_Constants.GB,new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                }
                                else{
                                    pMonthly.add(new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                    prodMap.put(productSizeRec.Duration__c+RMEC_Constants.DASH+ps+EC_Constants.GB,new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                }
                                /* BIZ-1490 */
                            }
                            if((integer.valueOf(pS) <= productSizeRec.End_License_Size__c) && (integer.valueOf(pS) >= productSizeRec.Start_License_Size__c) && (productSizeRec.Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)) && (productSizeRec.Region__c.equalsIgnoreCase(region)) && (productSizeRec.Active__c == true)){
                                Decimal tempProRatedPrice;
                                Decimal perGbPrice = productSizeRec.Price__c;
                                if(fRec != null && fRec.Enable__c){
                                    perGbPrice = productSizeRec.Price__c/1000;
                                }
                                if(cldInst.Size_GB__c != null && !cldInst.InstanceType__c.equalsIgnoreCase(Label.CLOUDSTACK_INSTANCE_TYPE_POC)){ //BIZ-1490
                                    if(tdays == 0)
                                    {
                                        tempProRatedPrice = 0;
                                    }
                                    else
                                    {
                                        tempProRatedPrice = (integer.valueOf(pS) - cldInst.Size_GB__c)*(perGbPrice)*daysleft/tdays;
                                    }   
                                } 
                                else {
                                    tempProRatedPrice = integer.valueOf(pS) * perGbPrice;
                                }
                /* BIZ-1490 */
                                Boolean isactive = false;
                                if(cldInst.InstanceType__c.equalsIgnoreCase(Label.RMBD_INSTTYPEPOC)){
                                    if(integer.valueOf(pS) >= cldInst.Size_GB__c){
                                        isactive = true;
                                    }
                                }else if(cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_PAID)){
                                    if(integer.valueOf(pS) > cldInst.Size_GB__c){
                                        isactive = true;
                                    }
                                }
                                else{
                                    isactive = true;
                                }
                                if(productSizeRec.Duration__c.equalsIgnoreCase(existingPlan)){
                                    pAnually.add(new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                    prodMap.put(productSizeRec.Duration__c+RMEC_Constants.DASH+ps+EC_Constants.GB,new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                }
                                else{
                                    pAnually.add(new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                    prodMap.put(productSizeRec.Duration__c+RMEC_Constants.DASH+ps+EC_Constants.GB,new ProductWrapper(productSizeRec.Product_Code__c,pS,integer.valueOf(pS)*perGbPrice,productSizeRec.Duration__c, isactive,tempProRatedPrice, false, EC_Constants.BLANK,Integer.valueOf(integer.valueOF(ps)*contentMapping.Per_GB_Storage__c)));
                                } 
                /* BIZ-1490 */                               
                            }                           
                        }   
                    }
                }
            }
        }

        if(!recommendedSizeList.isEmpty() && !(cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL))){
            if(!test.isRunningTest()){
                if(cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c != null && cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)){ //BIZ-1490
                    recommendedSize = cldInst.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c+RMEC_Constants.DASH+String.valueOf(recommendedSizeList[0])+EC_Constants.GB;
                }
                else{
                    recommendedSize = RMEC_Constants.ANNUALLY+RMEC_Constants.DASH+String.valueOf(recommendedSizeList[0])+EC_Constants.GB;
                }
            }

        }
        else if(!recommendedSizeList.isEmpty() && cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL)){
            recommendedSize = RMEC_Constants.ANNUALLY+RMEC_Constants.DASH+String.valueOf(recommendedSizeList[0])+EC_Constants.GB;
            //For Trail To Paid Upgrade Highlight the recomended banner for monthly
            recommendedSizeForTrial = RMEC_Constants.MONTHLY+RMEC_Constants.DASH+String.valueOf(recommendedSizeList[0])+EC_Constants.GB;
        }
        refreshPriceInfo();
    }
    /**
        * Name: setRegion()
        * Description: This method is to identify the region of the customer
        * @param NA
        * @return NA
    **/   
    public void setRegion(){
        if(string.isblank(ipAddress)){
            ipAddress= apexpages.currentpage().getheaders().get(system.label.RMEC_X_Salesforce_SIP); 
        }
        if(!Test.isRunningTest()){ 
            geoIpHttpResponse =  RMEC_Utility.GeoIpCallOut(ipAddress);
            }else{
            geoIpHttpResponse = new HttpResponse();
            geoIpHttpResponse.setBody(System.Label.RMEC_SETBODY_US);
            geoIpHttpResponse.setStatusCode(200);
        }
        string country = EC_Constants.BLANK;
        string countryCode = EC_Constants.BLANK;
        string regionCode = EC_Constants.BLANK;
        if(geoIpHttpResponse.getbody()!=null && geoIpHttpResponse.getbody()!=EC_Constants.BLANK && geoIpHttpResponse.getStatusCode() ==200 && !Test.isRunningTest()){

            resObj = new RMEC_GeoIpResponseParser();
            resObj = RMEC_GeoIpResponseParser.parse(geoIpHttpResponse.getbody());
            countryCode = resObj.message.country_code;
            regionCode = resObj.message.region;
            country = resObj.message.country_name;          
            } else { 
            countryCode= System.Label.RMEC_DEFAULT_COUNTRY_CODE.trim();
        }        
        boolean isValidAddress = true;
        Set<String> invalidCountryCodes = RMEC_Utility.splitString(System.Label.RMEC_UKRAINE_COUNTRY);
        if(!string.isblank(country) && invalidCountryCodes.contains(country.toUpperCase())) {
            isValidAddress = RMEC_Utility.checkInvalidRegion(regionCode,EC_Constants.BLANK,EC_Constants.BLANK);         
        }
        if(!isValidAddress){
            region = null;
        }
        else {
            List<Country__c> addrList = [select Name,Country__c,Country_Code__c,Region__c from Country__c where Country_Code__c =:countryCode LIMIT 1];
            List<Transformer__c> transformerList =  new List<Transformer__c>();
            if(addrList!=null && !addrList.isEmpty() && addrList[0].Country__c!=null) {
                transformerList = [SELECT Geo_Zone__c FROM Transformer__c WHERE Object_Type__c =: System.Label.TRANSFORMER_OBJECT_TYPE_CONTACT AND Input_Field__c =: System.Label.TRANSFORMER_INPUT_FIELD_MAILINGCOUNTRY AND Input_Value__c=:addrList[0].Country__c LIMIT 1];
            }
            if(!transformerList.isEmpty()) {
                region = RMEC_Utility.checkRegion(addrList[0].Region__c,transformerList[0].Geo_Zone__c,addrList[0].Country__c)[0];
                if(region == null){
                    contactSales=true;
                    contactSalesMessage = Label.RMEC_CONTACT_SALES_MSG_1+RMEC_Constants.CONTACT_SALES_MSG1;
                }
                }else{
                region = System.Label.RMEC_Default_Region.trim();
            }
        }
    }
    /****************************************************************************************************************************************************
        * Name: refreshPriceInfo
        * Description: This method is refresh price information
        * @parameters: NA
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public void refreshPriceInfo() {
        /*  correction in formula in getting the proRatedPrice */
        if(prodMap.containskey(selectedSize)){
            prodWrapObj = prodMap.get(selectedSize);

        }
    }
    /****************************************************************************************************************************************************
        * Name: addCart
        * Description: This method is used to add product
        * @parameters: NA
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public PageReference addCart(){
        isdisabled = false;
        refreshPriceInfo();
        return null;
    } 
    /****************************************************************************************************************************************************
        * Name: CheckOut
        * Description: method to navigate create shopping cart
        * @parameters: NA
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public PageReference CheckOut(){
        addCart();
        shopCartOperation();
        PageReference pgRef = Page.RMEC_BillingPaymentPage;
        pgRef.getParameters().put(RMEC_Constants.PROD,contentMapping.Name); //@AV
        pgRef.getParameters().put('showpopup','false');
        if(ApexPages.currentPage().getParameters().get(RMEC_Constants.FRM_PARAMETER)!=null && ApexPages.currentPage().getParameters().get(RMEC_Constants.FRM_PARAMETER).equalsIgnoreCase(RMEC_Constants.ROP_PARAMETER_VALUE)){
            pgRef.getParameters().put(RMEC_Constants.EDT_PARAMETER,System.Label.RMEC_PUT_PARAMETER_B);
        }
        pgRef.setRedirect(true);
        return pgRef;
    }
    /****************************************************************************************************************************************************
        * Name: shopCartOperation
        * Description: This method is perform Shopping Cart operations
        * @parameters: NA
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public void shopCartOperation(){ 
        List<Product2> prodList = [SELECT Id FROM Product2 WHERE ProductCode=:prodWrapObj.productId AND IsActive = true LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())];
        sizeProdList = prodWrapObj.size_GB.split(System.Label.PRODUCT_SPLIT_GB,2);               
        if(!shopCartItemList.isEmpty()){
            List<Shopping_Cart_Item__c> shopCartItemUpdateList = new List<Shopping_Cart_Item__c>();
            for(Shopping_Cart_Item__c shopCartItem :shopCartItemList){              
                shopCartItem.Subscription_Duration__c = prodWrapObj.duration;
                shopCartItem.Price_Book__c = Label.RMEC_FPX_Pricebook_Id;
                if(cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL) || cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_POC)){ //BIZ-1490
                    shopCartItem.Purchase_Type__c = RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_NEW;
                }
                else{
                    shopCartItem.Purchase_Type__c = RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE;
                }
                shopCartItem.Product_Size__c = integer.valueOF(sizeProdList[0]);
                if(prodList!=null && !prodList.isEmpty()) {
                    shopCartItem.Product__c = prodList[0].Id;
                }
                shopCartItem.Quantity__c = 1.0;
                shopCartItem.Region__c = region;
                shopCartItem.Status__c = RMEC_Constants.INCART;
                shopCartItem.RecordTypeId = Label.RMEC_eCOMMERCE_RECORD_TYPE_ID;
                shopCartItem.Product_Type__c = contentMapping.Product_Name__c;
                shopCartItem.Sub_Total__c = prodWrapObj.proRatedPrice;
                if(instId!= null && instId!= EC_Constants.BLANK){
                    shopCartItem.Trial_Id__c = instId;
                }
                shopCartItem.Shopping_cart__c = shopCart.Id;
                shopCartItemUpdateList.add(shopCartItem);
            }
            if(!shopCartItemUpdateList.isEmpty()){   
                Database.SaveResult[] saveResultList = Database.update(shopCartItemUpdateList,false);               
                for (Database.SaveResult res : saveResultList) {
                    if (!res.isSuccess()){
                        if (res.getErrors().size() > 0) { /*if any error occurs create error log entry*/   CreateApexErrorLog.insertHandledExceptions(null, saveResultList, null, null, EC_Constants.EL_CLASS, EC_Constants.OBJECT_SHOPPING_CART_ITEM,RMEC_Constants.CLASS_RMEC_UPGRADECOMPONENTCONTROLLER);     break;    }
                    }
                }           
            }           
        }
        else{
            if(!String.isBlank(contactId) && contactId != EC_Constants.BLANK){
                shopcart.Contact__c = contactId;
            }
            /* MODIFIED START FOR ERROR LOG FIX */
            if(shopcart != null && shopcart.Id == null){
                Database.SaveResult saveResult = Database.insert(shopcart,false);
                if (!saveResult.isSuccess() && saveResult.getErrors().size() > 0) {
                    CreateApexErrorLog.forSingleRecord(null, saveResult, null, null, EC_Constants.EL_CLASS, EC_Constants.OBJECT_SHOPPING_CART, RMEC_Constants.CLASS_RMEC_UPGRADECOMPONENTCONTROLLER);
                }
            }
            else if(shopcart != null && shopcart.Id != null){
                Database.SaveResult saveResult = Database.update(shopcart,false); 
                if (!saveResult.isSuccess() && saveResult.getErrors().size() > 0) {
                    CreateApexErrorLog.forSingleRecord(null, saveResult, null, null, EC_Constants.EL_CLASS, EC_Constants.OBJECT_SHOPPING_CART, RMEC_Constants.CLASS_RMEC_UPGRADECOMPONENTCONTROLLER);
                    //CreateApexErrorLog.insertErrorLogsforSingleRecord(null, saveResult, null, null,null, EC_Constants.EL_CLASS, RMEC_Constants.CLASS_RMEC_UPGRADECOMPONENTCONTROLLER,'shopCartOperation', EC_Constants.OBJECT_SHOPPING_CART,shopcart);
                }
            }
            /* MODIFIED END FOR ERROR LOG FIX */
            Shopping_Cart_Item__c shopCartItem = new Shopping_Cart_Item__c ();
            shopCartItem.Subscription_Duration__c = prodWrapObj.duration;
            if(!Test.isRunningTest()){
                shopCartItem.Price_Book__c = Label.RMEC_FPX_Pricebook_Id;
            }
            else{
                shopCartItem.Price_Book__c = Test.getStandardPricebookId();
            }
            if(cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_TRIAL) || cldInst.InstanceType__c.equalsIgnoreCase(RMEC_Constants.CLOUDSTACK_INSTANCE_TYPE_POC)){ //BIZ-1490
                shopCartItem.Purchase_Type__c = RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_NEW;
            }
            else{
                shopCartItem.Purchase_Type__c = RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE;
            }
            shopCartItem.Product_Size__c = integer.valueOF(sizeProdList[0]);
            if(prodList!=null && !prodList.isEmpty()) {
                shopCartItem.Product__c = prodList[0].Id;
            }
            shopCartItem.Quantity__c = 1.0;
            shopCartItem.Region__c = region;
            shopCartItem.Status__c = RMEC_Constants.INCART;
            shopCartItem.RecordTypeId = Label.RMEC_eCOMMERCE_RECORD_TYPE_ID;
            shopCartItem.Product_Type__c = contentMapping.Product_Name__c;
            shopCartItem.Sub_Total__c = prodWrapObj.proRatedPrice;
            shopCartItem.Shopping_cart__c = shopcart.id;
            if(instId!= null && instId!= EC_Constants.BLANK){
                shopCartItem.Trial_Id__c = instId;
            }
            Database.SaveResult saveResult = Database.insert(shopCartItem,false);
            if (!saveResult.isSuccess() && saveResult.getErrors().size() > 0) {
                CreateApexErrorLog.forSingleRecord(null, saveResult, null, null, EC_Constants.EL_CLASS, EC_Constants.OBJECT_SHOPPING_CART_ITEM, RMEC_Constants.CLASS_RMEC_UPGRADECOMPONENTCONTROLLER);
            }
        }
    }
    /****************************************************************************************************************************************************
        * Name: ProductWrapper
        * Description: Wrapper Class
        * @parameters: NA
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public class ProductWrapper{
        public String productId{get;set;}    
        public String size_GB{get;set;}
        public Integer gbStorage {get;set;}
        public decimal price{get;set;}
        public string duration{get;set;} 
        public string durationDisplay{get;set;}
        public decimal prodPriceMonthly{get;set;}
        public boolean active{get;set;}
        public decimal proRatedPrice{get;set;}
        public boolean isTrial{get;set;}
        public String trialProduct{get;set;}
          /**
        * @description: 
        * @param: 
        * @return: 
    **/  
        public ProductWrapper(){
            this.productId = EC_Constants.BLANK;
            this.size_GB = RMEC_Constants.SELECT_BELOW;
            this.price = 0;
            this.gbStorage = 0;
            this.duration = RMEC_Constants.ANNUALLY;
            this.durationDisplay = RMEC_Constants.DUE_ANNUALLY;
            this.active = true;
            this.proRatedPrice = 0;
            this.isTrial = false;
            this.trialProduct = EC_Constants.BLANK;
        }  
            /**
        * @description: 
        * @param: 
        * @return: 
    **/  
        public ProductWrapper(String proId,String size,decimal proPrice,String dur, boolean ac, decimal proRated, boolean t,String tp, integer perGB){
            this.isTrial = t;
            this.trialProduct = tp;
            this.productId = EC_Constants.BLANK+proId;
            this.size_GB =EC_Constants.BLANK+size+EC_Constants.GB;
            if(isTrial){
                this.durationDisplay = EC_Constants.BLANK;
            }
            this.gbStorage  = perGB;
            this.price = proPrice;
            this.duration = dur;
            if(dur.equalsIgnoreCase(RMEC_Constants.MONTHLY) && !isTrial){
                this.durationDisplay = RMEC_Constants.DUE_MONTHLY;
                this.prodPriceMonthly= proPrice;
            }
            else if(dur.equalsIgnoreCase(RMEC_Constants.ANNUALLY) && !isTrial){
                this.durationDisplay = RMEC_Constants.DUE_ANNUALLY;
                this.prodPriceMonthly= proPrice/12;
            }
            this.active = ac;
            this.proRatedPrice = proRated.setScale(2);
        }
    }
}