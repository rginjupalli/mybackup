/************************************************************************************************************************************************************
    Name:           RMEC_PaymentProcessingController 
    Description:    This class is used as a master controller class for controlling the flow for RainMkr product purchase.
    Author:         Accenture
    Date                PRJ/DFCT/ENHC#              Summary of Changes 
    ---------------     ------------------      ------------------------------
    19 Feb  2015         eCommerce - RainMkr          Initial Release       
    03 Sept 2015         RainMakr MVP2          Enhancements    
    30 mar 2016         RainMakr Balderdash     Enhancements
                                                                                
*************************************************************************************************************************************************************/
public class RMEC_PaymentProcessingController {
    public String shopCartId{get;set;}
    public String tokenId{get;set;}
    public User loggedInUser;
    public List<Shopping_Cart_Item__c> shopCartItemList;
    public List<Shopping_Cart_Item__c> updateShoppingCartItemList;
    public EC_PaymentDetailController paymentDetail {
        get{
            return this.paymentDetail;
        }
        set{
            paymentDetail = value;      
        }
    }
    public string error{get;set;}
    public List<Country__c> region;
    public decimal productPrice;
    public String stripePublishableKey {get;set;}
    public String prodPriceMonthly{get;set;}
    public String prodType{get;set;}
    public String planInterval;
    public Boolean popUp{get;set;}
    public Integer instanceCount{get;set;}
    /**********************************************************************************************************************************************************
        * Name:  RMEC_PaymentProcessingController
        * Description: The constructor of the class RMEC_PaymentProcessingController   
    ************************************************************************************************************************************************************/  
    public RMEC_PaymentProcessingController (){
    // added by Rishi to show pop up before procceding payment
    popUp=false;
    instanceCount=0;
    User loginUser=[Select id,ContactId from User Where Id=: userInfo.getUserId()];
    if(loginUser.ContactId !=null){
        try{
            List<Cloud_Stack__c> cloudStackList=[Select id,
                                                        Status__c,
                                                        End_Date__c 
                                                        From Cloud_Stack__c 
                                                        Where Contact__c =: loginUser.ContactId ];
            
            Splunk_Cloud_Role__c objSplunkRole = [Select id,
                                                        Instance_Role__r.Name,
                                                        Purchase_Role__c 
                                                        From Splunk_Cloud_Role__c
                                                        Where Splunk_Cloud_Contact__C =: loginUser.ContactId 
                                                        AND Instance_Role__r.Name = 'Admin'
                                                        AND Purchase_Role__c = 'Owner'Limit 1];
                                                        
            List<Order> orderList = [Select id,
                                            BillToContactId,
                                            Status,
                                            EndDate 
                                            From Order 
                                            Where BillToContactId =: loginUser.ContactId];
        
            Boolean isCloudStack=false;
            if(!cloudStackList.isEmpty()){
                
                for(Cloud_Stack__c CS: cloudStackList){
                    if(CS.End_Date__c.addDays(10) > Date.Today() && CS.Status__c != 'DELETE_COMPLETE'){
                        if(isCloudStack == false)
                            isCloudStack = true;
                        
                        instanceCount++;
                    }           
                }                   
            }
            Boolean isOrder=false;
            if(!orderList.isEmpty()){
                for(Order objOrder: orderList){
                    if((objOrder.status == 'Open' || objOrder.EndDate.addDays(10) > Date.Today() )&& isOrder == false){
                        isOrder=true;
                    }       
                }              
            }
            if(isCloudStack && objSplunkRole.Instance_Role__r.Name == 'Admin' && objSplunkRole.Purchase_Role__c == 'Owner' && isOrder){
                popUp=true;     
            }           
        }
        Catch(Exception ex){
            system.debug('error===='+ex+' line number==='+ex.getLineNumber());
        }
    }
        paymentDetail = new EC_PaymentDetailController ();          
    }    
    /****************************************************************************************************************************************************
        * Name: checkUser
        * Description: This method is called on load of page and it is used to validate the logged in user and product to be purchased.
        * @parameters: NA
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public void checkUser(){
        onload();
        error=RMEC_Constants.NoError; 
        paymentDetail.totalTax = 0.00; 
        shopCartId = ApexPages.currentPage().getParameters().get(RMEC_Constants.SCID);
        String editsection = EC_CONSTANTS.BLANK;
        editsection = ApexPages.currentPage().getParameters().get(RMEC_Constants.EDT_PARAMETER);
        paymentDetail.isRenew = ApexPages.currentPage().getParameters().get(RMEC_Constants.RNW);
        User loggedInUser = [select Id,ContactId,Contact.splunk_com_username__c,Contact.Geo__c,Contact.Region__c,Contact.MailingCity,Contact.MailingState,Contact.MailingPostalCode,Contact.MailingStreet,Contact.FirstName,Contact.LastName,Contact.Phone,Contact.Company_Name__c,Contact.MailingCountry,CP_Lead_Id__c,Email from User where Id =: UserInfo.getUserId() LIMIT 1];
        List<Lead> loggedInLeadList= new List<Lead>();
        /* BIZ-1182 */
        if(loggedInUser.CP_Lead_Id__c != null) {
            loggedInLeadList = [select Id,isConverted,Geo__c,Region__c,Country, City, State from Lead where Id=:loggedInUser.CP_Lead_Id__c LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1];
        }
        /* BIZ-1182 */
        String geoLocation=EC_CONSTANTS.BLANK;
        String tempRegion=EC_CONSTANTS.BLANK;
        String country=EC_CONSTANTS.BLANK;
        String region=EC_CONSTANTS.BLANK;
        String tempCity=EC_CONSTANTS.BLANK;
        String tempState=EC_CONSTANTS.BLANK;
        if(loggedInUser.ContactId != null && loggedInUser.Contact.Geo__c != null){
            geoLocation = loggedInUser.Contact.Geo__c;
            tempRegion = loggedInUser.Contact.Region__c;
            country = loggedInUser.Contact.MailingCountry;
            tempCity = loggedInUser.Contact.MailingCity;
            tempState = loggedInUser.Contact.MailingState;
        }
        else if(loggedInUser.CP_Lead_Id__c !=null && !loggedInUser.CP_Lead_Id__c.equals(EC_Constants.BLANK)){            
            if(!loggedInLeadList.isEmpty() && loggedInLeadList[0].Id!=null && loggedInLeadList[0].Geo__c !=null && loggedInLeadList[0].Country!=null){
                geoLocation = loggedInLeadList[0].Geo__c;
                tempRegion = loggedInLeadList[0].Region__c;
                country = loggedInLeadList[0].Country;            
                tempCity = loggedInLeadList[0].City;
                tempState = loggedInLeadList[0].State;            
            }
        }
        if(loggedInUser.ContactId != null){            
            boolean isValidAddress = true;
            Set<String> invalidCountryCodes = RMEC_Utility.splitString(System.Label.RMEC_UKRAINE_COUNTRY);
            if(country != null &&  invalidCountryCodes.contains(country.toUpperCase())) {
                isValidAddress = RMEC_Utility.checkInvalidRegion(EC_Constants.BLANK,tempCity,tempState); 
            }
            if(!isValidAddress){
                region = null;
            }
            else if(geoLocation != null && !geoLocation.equals(EC_Constants.BLANK)) {
                region = RMEC_Utility.checkRegion(geoLocation,tempRegion,country)[0];
            }
            else {
                region = EC_Constants.BLANK;
            }
            if(region == null) {
                error = RMEC_Constants.INVALID_REGION_ERROR;                
            }
            if(error.equals(RMEC_Constants.NoError)) {
                paymentDetail.contactEmail  = loggedInUser.Email;
                paymentDetail.loggedInContactId = loggedInUser.ContactId;
                Functionality_Enable_Disable__c fRec = Functionality_Enable_Disable__c.getValues(System.Label.RAIN_MAKR_LOWERPRICE);
                if(!String.isBlank(shopCartId)&& string.ValueOf(shopCartId) != EC_Constants.BLANK){
                    Decimal Amount = 0.0;
                    List<Shopping_Cart__c> shopCart = [select Id,Lead__c,Contact__c,Total_Size__c from Shopping_Cart__c where Contact__c=: loggedInUser.ContactId  LIMIT 1];
                    
                    shopCartItemList = new List<Shopping_cart_Item__c>();
                    shopCartItemList = [select Id,Product__r.Terms_of_Service_Text__c,Product__r.Tax_Code__c,Product__r.License_Template__c,Product__r.NoQuotaEnforcement_Template__c,Subscription_Duration__c,Region__c,Sub_Total__c,Total_Amount__c,Product__r.Ava_TaxCode__c,Trial_Id__c, Price_Book__r.Name,is_Product_Size_Editable__c,Selected_Size__c,Price_Book__c,Product__r.ProductCode,Product__r.Item_Category__c,Quantity__c,Purchase_Type__c,Product_Type__c,Product_Size__c,Product__c,Name,Status__c,Shopping_cart__c from Shopping_Cart_Item__c where Shopping_Cart__c =: shopCartId AND RecordTypeId =: Label.RMEC_eCOMMERCE_RECORD_TYPE_ID AND Purchase_Type__c != null LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1];

                    if(!shopCartItemList.isEmpty() && shopCartItemList[0].Purchase_Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_NEW) && (shopCartItemList[0].Trial_Id__c != null && !(shopCartItemList[0].Trial_Id__c.equals(EC_Constants.BLANK)))){
                        if(paymentDetail.isRenew.equalsIgnoreCase(RMEC_Constants.Y)){
                            paymentDetail.isTrailUpgrade = true;
                        }                     
                    }

                    String temp=EC_CONSTANTS.BLANK;
                    if(!shopCartItemList.isEmpty() && shopCartItemList[0].Product_Type__c != null){
                        temp = shopCartItemList[0].Product_Type__c;
                        temp = temp.trim();
                        temp = temp.replaceAll(RMEC_Constants.REPLACESPACE, EC_Constants.BLANK);
                    }
                    else{
                        temp = Label.RMEC2_DefaultProduct;
                    }
                    if(!shopCartItemList.isEmpty() && shopCartItemList[0].Purchase_Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE)){
                        temp += shopCartItemList[0].Purchase_Type__c;
                    }
                    paymentDetail.rmecCMS = RMEC_Content_Management_Setting__c.getValues(temp);
                    if(paymentDetail.rmecCMS.Type__c != null && paymentDetail.rmecCMS.Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE)){
                        paymentDetail.isUpgrade = true;
                    }
                    prodType = paymentDetail.rmecCMS.Product_Name_Display__c;
                    if(!shopCartItemList.isEmpty() && shopCartItemList[0].Purchase_Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE)){
                        paymentDetail.existingStack = [Select Size_GB__c, Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c, Fulfillment_Case__r.Subscription_Payment__r.Subscription_Start_Date__c, Fulfillment_Case__r.Subscription_Payment__r.Subscription_End_Date__c from Cloud_Stack__c Where Id =: shopCartItemList[0].Trial_Id__c LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1];
                        if(paymentDetail.existingStack.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)){      
                            planInterval = RMEC_Constants.MONTHLY;
                        }
                        else{
                            planInterval = RMEC_Constants.ANNUALLY;
                        }
                    }

                    
                    if(shopCartItemList.isEmpty()){                     
                        if(shopCart!= null && shopCart.size() >0){
                            shopCartItemList = new List<Shopping_cart_Item__c>([select Id,Product__r.Terms_of_Service_Text__c,Product__r.Tax_Code__c,Product__r.License_Template__c,Product__r.NoQuotaEnforcement_Template__c,Subscription_Duration__c,Region__c,Sub_Total__c,Total_Amount__c,Product__r.Ava_TaxCode__c, Price_Book__r.Name,is_Product_Size_Editable__c,Product_Type__c,Selected_Size__c,Price_Book__c,Product__r.ProductCode,Trial_Id__c,Product__r.Item_Category__c,Quantity__c,Purchase_Type__c,Product_Size__c,Product__c,Name,Status__c,Shopping_cart__c from Shopping_Cart_Item__c where Shopping_Cart__c =: shopCart[0].id AND Status__c=:RMEC_Constants.INCART AND RecordTypeId =: Label.RMEC_eCOMMERCE_RECORD_TYPE_ID LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1]);
                           
                            if(shopCartItemList != null && !shopCartItemList.isEmpty()){
                                //recalculation of product prizes based on logged in contact's Geo location
                                
                                if((editsection == null || editsection.equals(EC_Constants.BLANK)) && region != null && shopCartId != null && !shopCartId.equals(EC_Constants.BLANK)){
                                    List<RMEC_Product_Size_Mapping__c> productSizeList = [SELECT Price__c FROM RMEC_Product_Size_Mapping__c WHERE Active__c=true AND Product_Code__c=:shopCartItemList[0].Product__r.ProductCode AND End_License_Size__c >=:shopCartItemList[0].Product_Size__c AND Start_License_Size__c<=:shopCartItemList[0].Product_Size__c AND Duration__c=:shopCartItemList[0].Subscription_Duration__c AND Region__c=:region LIMIT 1];
                                    if(productSizeList != null && !productSizeList.isEmpty()) {
                                        Decimal pPrice = productSizeList[0].Price__c;
                                        if(fRec != null && fRec.Enable__c && loggedInUser.Contact.splunk_com_username__c.endsWith(System.Label.RMEC_TestUserName)){
                                            if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)) {
                                                pPrice = pPrice/100;
                                            }
                                            else if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)) {
                                                pPrice = pPrice/1000;
                                            }                       
                                        }                               
                                        shopCartItemList[0].Sub_Total__c= integer.valueOf(shopCartItemList[0].Product_Size__c)*pPrice;                                  
                                    }
                                    if(shopCartItemList[0].Region__c != region){
                                        shopCartItemList[0].Region__c = region;
                                    }
                                }
                                paymentDetail.grandTotal = shopCartItemList[0].Sub_Total__c;
                                paymentDetail.productSize = shopCartItemList[0].Product_Size__c;
                                Integer toMultiply = Integer.valueOf(paymentDetail.rmecCMS.per_GB_Storage__c);
                                if(shopCartItemList[0].Product_Size__c != null){
                                    paymentDetail.totalStorage = Integer.valueOf(shopCartItemList[0].Product_Size__c * toMultiply);  
                                }                        
                                paymentDetail.subTotal =shopCartItemList[0].Sub_Total__c;
                                paymentDetail.UnitPrice =shopCartItemList[0].Sub_Total__c;
                                paymentDetail.Duration=  RMEC_Constants.DUE+ String.valueOf(shopCartItemList[0].Subscription_Duration__c).toUpperCase();
                                if(String.valueOf(shopCartItemList[0].Subscription_Duration__c).equalsIgnoreCase(RMEC_Constants.ANNUALLY)){
                                    paymentDetail.Duration = RMEC_Constants.DUE+ RMEC_Constants.YEARLY.toUpperCase();
                                }
                                //Update region in shopping cart
                                if(shopCartItemList[0].Subscription_Duration__c != null && shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)){
                                    paymentDetail.totalValMonthly = paymentDetail.subTotal/12;
                                    paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Annual;
                                    }else{
                                    paymentDetail.totalValMonthly = paymentDetail.subTotal;
                                    paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Month;
                                }
                                paymentDetail.totalVal = paymentDetail.subTotal;
                                paymentDetail.totalValDecimal = paymentDetail.subTotal.setscale(2);  
                                paymentDetail.shoppingCartItemList = shopCartItemList;
                                paymentDetail.isShoppingCartEmpty = false;
                                if(shopCartItemList[0].Trial_Id__c!=EC_Constants.BLANK && shopCartItemList[0].Trial_Id__c!=null){
                                    paymentDetail.trialId = shopCartItemList[0].Trial_Id__c;
                                }
                            }
                        }
                        else{
                            error = RMEC_Constants.NOSHOPPING;
                        }
                    }
                    else{
                        if(shopCart!= null && shopCart.size() >0){
                            if(!shopCart[0].Id.equals(shopCartId)){
                                //Remove existing In-Cart Shopping Cart Items
                                List<Shopping_Cart_Item__c> existingShopCartItem = new List<Shopping_cart_Item__c>([Select Id from Shopping_Cart_Item__c where Shopping_Cart__c =: shopCart[0].Id AND Status__c=:RMEC_Constants.INCART AND RecordTypeId =: Label.RMEC_eCOMMERCE_RECORD_TYPE_ID LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1]);
                                if(!existingShopCartItem.isEmpty()){
                                    Database.DeleteResult[] deleteResultList = Database.delete(existingShopCartItem,false);
                                    for (Database.DeleteResult res : deleteResultList) {
                                        if (!res.isSuccess()){if (res.getErrors().size() > 0) {CreateApexErrorLog.insertHandledExceptions(null, null, deleteResultList, null, RMEC_Constants.EL_CLASS, RMEC_Constants.OBJECT_SHOPPING_CART_ITEM,RMEC_Constants.Class_RMEC_PAYMENTPROCESSINGCOMPONENTCONTROLLER);error=RMEC_Constants.INSERTIONERROR;break;}}
                                    }  
                                }
                            }                        
                            //check the prices of product again on the basis of Geolocation of contact 
                            updateShoppingCartItemList = new List<Shopping_Cart_Item__c>();
                            if((editsection == null || editsection.equals(EC_Constants.BLANK)) && !String.isBlank(region) && !String.isBlank(shopCartId) && !shopCartId.equals(EC_Constants.BLANK)){
                                if(!shopCartItemList[0].Region__c.equalsIgnoreCase(region) || region.equalsIgnoreCase(EC_Constants.BLANK)){
                                    List<RMEC_Product_Size_Mapping__c> productSizeList = [SELECT Price__c FROM RMEC_Product_Size_Mapping__c WHERE Active__c=true AND Product_Code__c=:shopCartItemList[0].Product__r.ProductCode AND End_License_Size__c >=:shopCartItemList[0].Product_Size__c AND Start_License_Size__c<=:shopCartItemList[0].Product_Size__c AND Duration__c=:shopCartItemList[0].Subscription_Duration__c AND Region__c=:region LIMIT 1];
                                    if(productSizeList != null && !productSizeList.isEmpty()) {
                                        Decimal pPrice = productSizeList[0].Price__c;
                                        if(fRec != null && fRec.Enable__c && loggedInUser.Contact.splunk_com_username__c.endsWith(System.Label.RMEC_TestUserName)){
                                            if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)) {
                                                pPrice = pPrice/100;
                                            }
                                            else if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)) {
                                                pPrice = pPrice/1000;
                                            }                       
                                        }                               
                                        shopCartItemList[0].Sub_Total__c= integer.valueOf(shopCartItemList[0].Product_Size__c)*pPrice;                                  
                                    }
                                    shopCartItemList[0].Region__c = region;
                                }
                            }
                            shopCartItemList[0].Shopping_cart__c=shopCart[0].Id;
                            paymentDetail.grandTotal = shopCartItemList[0].Sub_Total__c;
                            paymentDetail.productSize = shopCartItemList[0].Product_Size__c;
                            Integer toMultiply = Integer.valueOf(paymentDetail.rmecCMS.per_GB_Storage__c);
                            paymentDetail.totalStorage = Integer.valueOf(shopCartItemList[0].Product_Size__c * toMultiply);    
                            paymentDetail.subTotal = shopCartItemList[0].Sub_Total__c;
                            paymentDetail.UnitPrice =shopCartItemList[0].Sub_Total__c;
                            paymentDetail.region =shopCartItemList[0].Region__c;
                            paymentDetail.Duration = RMEC_Constants.DUE+ String.valueOf(shopCartItemList[0].Subscription_Duration__c).toUpperCase();
                            if(String.valueOf(shopCartItemList[0].Subscription_Duration__c).equalsIgnoreCase(RMEC_Constants.ANNUALLY)){
                                paymentDetail.Duration = RMEC_Constants.DUE+ RMEC_Constants.YEARLY.toUpperCase();
                            }   
                            updateShoppingCartItemList.add(shopCartItemList[0]);                    
                            if(shopCartItemList[0].Subscription_Duration__c.equalsignoreCase(RMEC_Constants.ANNUALLY)){
                                paymentDetail.totalValMonthly = paymentDetail.subTotal/12;
                                paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Annual;
                                }else{
                                paymentDetail.totalValMonthly = paymentDetail.subTotal;
                                paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Month;
                            }
                            paymentDetail.totalVal = paymentDetail.subTotal; 
                            paymentDetail.totalValDecimal = paymentDetail.subTotal.setscale(2);   
                            if(shopCartItemList[0].Trial_Id__c!=EC_Constants.BLANK && shopCartItemList[0].Trial_Id__c!=null){
                                paymentDetail.trialId = shopCartItemList[0].Trial_Id__c;
                            }                      
                            paymentDetail.isShoppingCartEmpty = false;
                            if(updateShoppingCartItemList.size() > 0){            
                                Database.SaveResult[] saveResultList = Database.update(updateShoppingCartItemList,false);               
                                for (Database.SaveResult res : saveResultList) {
                                    if (!res.isSuccess()){if (res.getErrors().size() > 0) {CreateApexErrorLog.insertHandledExceptions(null, saveResultList, null, null, RMEC_Constants.EL_CLASS, RMEC_Constants.OBJECT_SHOPPING_CART_ITEM,RMEC_Constants.Class_RMEC_PAYMENTPROCESSINGCOMPONENTCONTROLLER);error=RMEC_Constants.INSERTIONERROR;break;}}
                                }           
                            }
                            paymentDetail.shoppingCartItemList = updateShoppingCartItemList;
                            /* BIZ-1182 */
                            if(shopCart[0].Lead__c == null && !loggedInLeadList.isEmpty() && !loggedInLeadList[0].isConverted) {
                                shopCart[0].Lead__c = loggedInLeadList[0].Id;
                            }
                            updateshopCart(shopCart[0]);
                            /* BIZ-1182 */
                        }
                        else {
                            Shopping_Cart__c shoppingCart = [select Id,Lead__c,Contact__c,Total_Size__c from Shopping_Cart__c where Id =: shopCartId LIMIT 1];
                            updateShoppingCartItemList =new List<Shopping_cart_Item__c>();
                            if((editsection == null || editsection.equals(EC_Constants.BLANK)) && region != null && shopCartId != null && !shopCartId.equals(EC_Constants.BLANK)){
                                List<RMEC_Product_Size_Mapping__c> productSizeList = [SELECT Price__c FROM RMEC_Product_Size_Mapping__c WHERE Active__c=true AND Product_Code__c=:shopCartItemList[0].Product__r.ProductCode AND End_License_Size__c >=:shopCartItemList[0].Product_Size__c AND Start_License_Size__c<=:shopCartItemList[0].Product_Size__c AND Duration__c=:shopCartItemList[0].Subscription_Duration__c AND Region__c=:region LIMIT 1];
                                if(productSizeList != null && !productSizeList.isEmpty()) {
                                    Decimal pPrice = productSizeList[0].Price__c;
                                    if(fRec != null && fRec.Enable__c && loggedInUser.Contact.splunk_com_username__c.endsWith(System.Label.RMEC_TestUserName)){
                                        if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)) {
                                            pPrice = pPrice/100;
                                        }
                                        else if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)) {
                                            pPrice = pPrice/1000;
                                        }                       
                                    }                               
                                    shopCartItemList[0].Sub_Total__c= integer.valueOf(shopCartItemList[0].Product_Size__c)*pPrice;                                  
                                }
                                if(shopCartItemList[0].Region__c != region){
                                    shopCartItemList[0].Region__c = region;
                                }
                            }
                            paymentDetail.productType = shopCartItemList[0].Purchase_Type__c;
                            paymentDetail.grandTotal = shopCartItemList[0].Sub_Total__c;
                            paymentDetail.productSize = shopCartItemList[0].Product_Size__c;
                            Integer toMultiply = Integer.valueOf(paymentDetail.rmecCMS.per_GB_Storage__c);
                            paymentDetail.totalStorage = Integer.valueOf(shopCartItemList[0].Product_Size__c * toMultiply);                          
                            paymentDetail.subTotal =shopCartItemList[0].Sub_Total__c;
                            paymentDetail.UnitPrice =shopCartItemList[0].Sub_Total__c;
                            paymentDetail.Duration=  RMEC_Constants.DUE+ String.valueOf(shopCartItemList[0].Subscription_Duration__c).toUpperCase();
                            if(String.valueOf(shopCartItemList[0].Subscription_Duration__c) == RMEC_Constants.ANNUALLY){
                                paymentDetail.Duration = RMEC_Constants.DUE+ RMEC_Constants.YEARLY.toUpperCase();
                            }
                            //Update region in shopping cart
                            if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)){
                                paymentDetail.totalValMonthly = paymentDetail.subTotal/12;
                                paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Annual;
                                }else{
                                paymentDetail.totalValMonthly = paymentDetail.subTotal;
                                paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Month;
                            }
                            paymentDetail.totalVal = paymentDetail.subTotal;
                            if(shopCartItemList[0].Trial_Id__c!=EC_Constants.BLANK && shopCartItemList[0].Trial_Id__c!=null){
                                paymentDetail.trialId = shopCartItemList[0].Trial_Id__c;
                            }
                            updateShoppingCartItemList.add(shopCartItemList[0]);  
                            paymentDetail.totalValDecimal = paymentDetail.subTotal.setscale(2);                   
                            paymentDetail.shoppingCartItemList = shopCartItemList;
                            paymentDetail.isShoppingCartEmpty = false;
                            shoppingCart.Contact__c =loggedInUser.ContactId;
                            /* BIZ-1182 */
                            if(shoppingCart.Lead__c == null && !loggedInLeadList.isEmpty() && !loggedInLeadList[0].isConverted) {
                                shoppingCart.Lead__c = loggedInLeadList[0].Id;
                            }
                            /* BIZ-1182 */
                            shopCartId = shoppingCart.Id;
                            updateshopCart(shoppingCart);
                            updateShoppingCartItems(updateShoppingCartItemList);
                        }
                    }
                    if(!paymentDetail.shoppingCartItemList.isEmpty()) {
                        paymentDetail.product_TOS = paymentDetail.shoppingCartItemList[0].product__r.Terms_of_Service_Text__c;
                    }
                }
                else{
                    List<Shopping_Cart__c> shopCart = [select Id,Contact__c,Total_Size__c from Shopping_Cart__c where Contact__c =: loggedInUser.ContactId LIMIT 1];
                    if(shopCart.size() > 0){
                        shopCartItemList = new List<Shopping_cart_Item__c>([select Id,Product__r.Terms_of_Service_Text__c,Product__r.Tax_Code__c,Product__r.License_Template__c,Subscription_Duration__c,Region__c,Sub_Total__c,Total_Amount__c,Product__r.Ava_TaxCode__c, Price_Book__r.Name,is_Product_Size_Editable__c,Product_Type__c,Selected_Size__c,Price_Book__c,Product__r.ProductCode,Trial_Id__c,Product__r.Item_Category__c,Product__r.NoQuotaEnforcement_Template__c,Quantity__c,Purchase_Type__c,Product_Size__c,Product__c,Name,Status__c,Shopping_cart__c from Shopping_Cart_Item__c where Shopping_Cart__c =: shopCart[0].id AND Status__c=:RMEC_Constants.INCART AND RecordTypeId =: Label.RMEC_eCOMMERCE_RECORD_TYPE_ID LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1]);
                        if(shopCartItemList != null && !shopCartItemList.isEmpty()){
                            String temp=EC_CONSTANTS.BLANK;
                            if(shopCartItemList[0].Product_Type__c != null){
                                temp = shopCartItemList[0].Product_Type__c;
                                temp = temp.trim();
                                temp = temp.replaceAll(RMEC_Constants.REPLACESPACE, EC_Constants.BLANK);
                            }
                            else{
                                temp = Label.RMEC2_DefaultProduct;
                            }
                            if(shopCartItemList[0].Purchase_Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE)){
                                temp += shopCartItemList[0].Purchase_Type__c;
                            }
                            paymentDetail.rmecCMS = RMEC_Content_Management_Setting__c.getValues(temp);
                            if(paymentDetail.rmecCMS.Type__c != null && paymentDetail.rmecCMS.Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE)){
                                paymentDetail.isUpgrade = true;
                            }
                            if(!shopCartItemList.isEmpty() && shopCartItemList[0].Purchase_Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_NEW) && (shopCartItemList[0].Trial_Id__c != null && !(shopCartItemList[0].Trial_Id__c.equals(EC_Constants.BLANK)))){
                                paymentDetail.isTrailUpgrade = true;
                            }
                            prodType = paymentDetail.rmecCMS.Product_Name_Display__c;
                            if(shopCartItemList[0].Purchase_Type__c.equalsIgnoreCase(RMEC_Constants.SUBSCRIPTION_PAYMENT_PURCHASE_TYPE_UPGRADE)){
                                paymentDetail.existingStack = [Select Size_GB__c, Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c, Fulfillment_Case__r.Subscription_Payment__r.Subscription_End_Date__c, Fulfillment_Case__r.Subscription_Payment__r.Subscription_Start_Date__c   from Cloud_Stack__c Where Id =: shopCartItemList[0].Trial_Id__c LIMIT:(Limits.getLimitQueryRows() - Limits.getQueryRows())-1 ];
                                if(paymentDetail.existingStack.Fulfillment_Case__r.Subscription_Payment__r.Plan_Interval__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)){      
                                    planInterval = RMEC_Constants.MONTHLY;
                                }
                                else{
                                    planInterval = RMEC_Constants.ANNUALLY;
                                }
                            }
                            //recalculation of product prizes based on logged in contact's Geo location
                           if((editsection == null || editsection.equals(EC_Constants.BLANK)) && region != null && shopCartId != null && !shopCartId.equals(EC_Constants.BLANK)){
                                List<RMEC_Product_Size_Mapping__c> productSizeList = [SELECT Price__c FROM RMEC_Product_Size_Mapping__c WHERE Active__c=true AND Product_Code__c=:shopCartItemList[0].Product__r.ProductCode AND End_License_Size__c >=:shopCartItemList[0].Product_Size__c AND Start_License_Size__c<=:shopCartItemList[0].Product_Size__c AND Duration__c=:shopCartItemList[0].Subscription_Duration__c AND Region__c=:region LIMIT 1];
                                if(productSizeList != null && !productSizeList.isEmpty()) {
                                    Decimal pPrice = productSizeList[0].Price__c;
                                    if(fRec != null && fRec.Enable__c && loggedInUser.Contact.splunk_com_username__c.endsWith(System.Label.RMEC_TestUserName)){
                                        if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.MONTHLY)) {
                                            pPrice = pPrice/100;
                                        }
                                        else if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)) {
                                            pPrice = pPrice/1000;
                                        }                       
                                    }                               
                                    shopCartItemList[0].Sub_Total__c= integer.valueOf(shopCartItemList[0].Product_Size__c)*pPrice;                                  
                                }
                                if(shopCartItemList[0].Region__c != region){
                                    shopCartItemList[0].Region__c = region;
                                }
                            }
                            paymentDetail.grandTotal = shopCartItemList[0].Sub_Total__c;
                            paymentDetail.productSize = shopCartItemList[0].Product_Size__c;
                            Integer toMultiply = Integer.valueOf(paymentDetail.rmecCMS.per_GB_Storage__c);
                            paymentDetail.totalStorage = Integer.valueOf(shopCartItemList[0].Product_Size__c * toMultiply);                          
                            paymentDetail.subTotal =shopCartItemList[0].Sub_Total__c;
                            paymentDetail.UnitPrice =shopCartItemList[0].Sub_Total__c;
                            paymentDetail.Duration=  RMEC_Constants.DUE+ String.valueOf(shopCartItemList[0].Subscription_Duration__c).toUpperCase();
                            if(String.valueOf(shopCartItemList[0].Subscription_Duration__c) == RMEC_Constants.ANNUALLY){
                                paymentDetail.Duration = RMEC_Constants.DUE+ RMEC_Constants.YEARLY.toUpperCase();
                            }
                            //Update region in shopping cart
                            if(shopCartItemList[0].Subscription_Duration__c.equalsIgnoreCase(RMEC_Constants.ANNUALLY)){
                                paymentDetail.totalValMonthly = paymentDetail.subTotal/12;
                                paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Annual;
                                }else{
                                paymentDetail.totalValMonthly = paymentDetail.subTotal;
                                paymentDetail.paymentMethod = RMEC_Constants.Product_Size_Duration_Period_Month;
                            }
                            paymentDetail.totalVal = paymentDetail.subTotal;
                            paymentDetail.totalValDecimal = paymentDetail.subTotal.setscale(2);  
                            paymentDetail.shoppingCartItemList = shopCartItemList;
                            paymentDetail.isShoppingCartEmpty = false;
                            if(shopCartItemList[0].Trial_Id__c!=EC_Constants.BLANK && shopCartItemList[0].Trial_Id__c!=null){
                                paymentDetail.trialId = shopCartItemList[0].Trial_Id__c;
                            }
                            paymentDetail.product_TOS = shopCartItemList[0].product__r.Terms_of_Service_Text__c;
                        }
                    }
                }
                List<Stripe_Customer__c> stripeCustomerList = new List<Stripe_Customer__c>();
                stripeCustomerList = [select id,Address_Line_1__c,Address_Line_2__c,Billing_Phone__c,Card_Type__c,City__c,Customer_Id__c,Country__c,Organization_Name__c,State__c, Zip_Code__c,Name__c,Contact__c,Last_4_Digit__c,Card_Brand__c,Card_Expiry_date__c,Billing_Address_Same_As_Shipping_Address__c,Billing_Name__c,Billing_Address_Line_1__c,Billing_Address_Line_2__c,Billing_City__c,Billing_Country__c,Billing_State__c,Billing_Zip_Code__c,Customer_Card_Id__c from Stripe_Customer__c where Contact__c = :loggedInUser.ContactId LIMIT 1];
                if(!stripeCustomerList.isEmpty()){
                    paymentDetail.stripeCustomerSfId = stripeCustomerList[0].Id;
                    paymentDetail.stripeCustomerId = stripeCustomerList[0].Customer_Id__c;
                    paymentDetail.customerShippingAddress_Line_1 = stripeCustomerList[0].Address_Line_1__c;
                    paymentDetail.customerShippingAddress_Line_2 = stripeCustomerList[0].Address_Line_2__c;
                    paymentDetail.customerShippingPhone = stripeCustomerList[0].Billing_Phone__c;
                    paymentDetail.customerShippingCity = stripeCustomerList[0].City__c;
                    paymentDetail.customerShippingCountry = stripeCustomerList[0].Country__c;
                    paymentDetail.customerShippingState = stripeCustomerList[0].State__c;
                    paymentDetail.selectedState = stripeCustomerList[0].State__c;
                    paymentDetail.customerShippingPostalCode = stripeCustomerList[0].Zip_Code__c;
                    paymentDetail.customerShippingCompanyName = stripeCustomerList[0].Organization_Name__c;
                    paymentDetail.cardBrand = stripeCustomerList[0].Card_Brand__c;
                    paymentDetail.cardExpiryDate = stripeCustomerList[0].Card_Expiry_date__c;
                    paymentDetail.cardLast4 = stripeCustomerList[0].Last_4_Digit__c;
                    paymentDetail.cardType = stripeCustomerList[0].Card_Type__c;                    
                    paymentDetail.sameAsShippingAdd = stripeCustomerList[0].Billing_Address_Same_As_Shipping_Address__c;
                    paymentDetail.customerNameOnBillingAddress = stripeCustomerList[0].Billing_Name__c;
                    paymentDetail.customerBillingAddress_Line_1 = stripeCustomerList[0].Billing_Address_Line_1__c;
                    paymentDetail.customerBillingAddress_Line_2 = stripeCustomerList[0].Billing_Address_Line_2__c;
                    paymentDetail.customerBillingCity = stripeCustomerList[0].Billing_City__c;
                    paymentDetail.customerBillingCountry = stripeCustomerList[0].Billing_Country__c;
                    paymentDetail.customerBillingState = stripeCustomerList[0].Billing_State__c;
                    paymentDetail.billingSelectedState = stripeCustomerList[0].Billing_State__c;
                    paymentDetail.customerBillingPostalCode = stripeCustomerList[0].Billing_Zip_Code__c;
                    paymentDetail.customerCardId = stripeCustomerList[0].Customer_Card_Id__c;
                    if(paymentDetail.cardLast4!=null && paymentDetail.cardBrand!=null){
                        paymentDetail.cardNumber = RMEC_Utility.getCardFormat(paymentDetail.cardBrand,paymentDetail.cardLast4);
                    }
                    List<string> namesList = stripeCustomerList[0].Name__c.split(EC_CONSTANTS.SPACE, 2);
                    if(!namesList.isEmpty()){
                        paymentDetail.firstName = namesList[0];
                        if(namesList.size()>1){
                            paymentDetail.lastName = namesList[1];
                        }
                    }
                    if(stripeCustomerList[0].Billing_Name__c != null) {
                        List<string> billNamesList = stripeCustomerList[0].Billing_Name__c.split(EC_CONSTANTS.SPACE, 2);
                        if(!billNamesList.isEmpty()){
                            paymentDetail.billingFirstName = billNamesList[0];
                            if(billNamesList.size()>1){
                                paymentDetail.billingLastName = billNamesList[1];
                            }
                        }
                    }
                    if(stripeCustomerList[0].Card_Expiry_date__c != null){
                        List<string> cardDetailList = stripeCustomerList[0].Card_Expiry_date__c.split(EC_CONSTANTS.BACK_SLASH,2);
                        paymentDetail.expMonth = cardDetailList[0];
                        paymentDetail.expYear = cardDetailList[1];                  
                    }
                }
                else {
                    paymentDetail.firstName = loggedInUser.Contact.FirstName;
                    paymentDetail.lastName = (loggedInUser.Contact.LastName != null)?loggedInUser.Contact.LastName:EC_Constants.BLANK;
                    paymentDetail.customerShippingAddress_Line_1 = (loggedInUser.Contact.MailingStreet != null)?loggedInUser.Contact.MailingStreet:EC_Constants.BLANK;
                    paymentDetail.customerShippingPhone = (loggedInUser.Contact.Phone != null)?loggedInUser.Contact.Phone:EC_Constants.BLANK;
                    paymentDetail.customerShippingCity = (loggedInUser.Contact.MailingCity != null)?loggedInUser.Contact.MailingCity:EC_Constants.BLANK;
                    paymentDetail.customerShippingCountry = (loggedInUser.Contact.MailingCountry != null)?loggedInUser.Contact.MailingCountry:EC_Constants.BLANK;
                    paymentDetail.customerShippingState = (loggedInUser.Contact.MailingState != null)?loggedInUser.Contact.MailingState:EC_Constants.BLANK;
                    paymentDetail.selectedState = (loggedInUser.Contact.MailingState != null)?loggedInUser.Contact.MailingState:EC_Constants.BLANK;
                    paymentDetail.customerShippingPostalCode = (loggedInUser.Contact.MailingPostalCode != null)?loggedInUser.Contact.MailingPostalCode:EC_Constants.BLANK;
                    paymentDetail.customerShippingCompanyName = (loggedInUser.Contact.Company_Name__c != null)?loggedInUser.Contact.Company_Name__c:EC_Constants.BLANK;
                    paymentDetail.sameAsShippingAdd = true;
                }
            }
        } 
        else {
            error=RMEC_Constants.NotValidContactError;
        }  
        
    }
    /****************************************************************************************************************************************************
        * Name: updateshopCart
        * Description: This method is used to update shopping cart
        * @parameters: Shopping_Cart__c shoppingCart
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public void updateshopCart(Shopping_Cart__c shoppingCart){
        try{
            if(error==RMEC_Constants.NoError){
                Database.update(shoppingCart,false);
            }
        }
        catch(exception e){
            CreateApexErrorLog.insertHandledExceptions(e, null, null, null, RMEC_Constants.EL_CLASS, RMEC_Constants.OBJECT_SHOPPING_CART, RMEC_Constants.Class_RMEC_PAYMENTPROCESSINGCOMPONENTCONTROLLER);error=RMEC_Constants.INSERTIONERROR;
        }
    }
    /****************************************************************************************************************************************************
        * Name: updateShoppingCartItems
        * Description: This method is used to update shopping cart items
        * @parameters: List<Shopping_Cart_Item__c> shopCartItemUpdateList
        * @return: NA
    *****************************************************************************************************************************************************/ 
    public void updateShoppingCartItems(List<Shopping_Cart_Item__c> shopCartItemUpdateList){
        if(error==RMEC_Constants.NoError){
            shopCartItemList = shopCartItemUpdateList;
            if(shopCartItemList.size() > 0){            
                Database.SaveResult[] saveResultList = Database.update(shopCartItemList,false);
                paymentDetail.shoppingCartItemList = shopCartItemList;
                for (Database.SaveResult res : saveResultList) {
                    if (!res.isSuccess()){if (res.getErrors().size() > 0) {CreateApexErrorLog.insertHandledExceptions(null, saveResultList, null, null, RMEC_Constants.EL_CLASS, RMEC_Constants.OBJECT_SHOPPING_CART_ITEM,RMEC_Constants.Class_RMEC_PAYMENTPROCESSINGCOMPONENTCONTROLLER);error=RMEC_Constants.INSERTIONERROR;break;}}
                }           
            }
        }
    }
    /****************************************************************************************************************************************************
        * Method Name: downloadInvoice
        * Description: This method is used to redirect on download Invoice Page.
        * @Parameter: <None>
        * @Return type:PageReference
    *****************************************************************************************************************************************************/
    public PageReference downloadInvoice(){
        PageReference pageRef = new PageReference(label.RMEC_InvoicePage_Path);
        pageRef.setRedirect(false);
        return pageRef;
    }
    /****************************************************************************************************************************************************
        * Method Name: goToWelcomePage
        * Description: This method is used to redirect on Welcome Page.
        * @Parameter: <None>
        * @Return type:PageReference
    *****************************************************************************************************************************************************/
    public PageReference goToWelcomePage() {
        PageReference pageRef = new PageReference(System.label.RMEC_RETURN_TO_SPLUNK);
        pageRef.getParameters().put(RMEC_Constants.SPAYID,paymentDetail.subPaymentId);
        pageRef.setRedirect(false);
        return pageRef;
    }
    /****************************************************************************************************************************************************
        * Method Name: goToInstancePage
        * Description: This method is used to redirect to Instance Page.
        * @Parameter: <None>
        * @Return type:PageReference
    *****************************************************************************************************************************************************/
    public PageReference goToInstancePage() {
        PageReference pageRef = new PageReference(System.label.RMEC_RETURN_TO_SPLUNK);
        pageRef.setRedirect(false);
        return pageRef;
    }
    /****************************************************************************************************************************************************
        * Method Name: onload
        * Description: This method is used to call the method for tracking Web Activity History
        * @Parameter: <None>
        * @Return type:PageReference
    *****************************************************************************************************************************************************/
    public void onload(){    
        User loggedInUser = [select Id,ContactId, Contact.Geo__c, Contact.Region__c,Contact.MailingCity,Contact.MailingState, Contact.MailingCountry,CP_Lead_Id__c from User where Id =: UserInfo.getUserId() Limit 1];
        Id contactId = loggedInUser.ContactId;
        Id LeadId = loggedInUser.CP_Lead_Id__c;
        String pageURL = ApexPages.CurrentPage().getUrl();
        if(UserInfo.getName() != RMEC_Constants.UserName){
            RMEC_Utility.webActivityHistory(contactId, pageURL, EC_Constants.BLANK, LeadId);
        }
    }
}