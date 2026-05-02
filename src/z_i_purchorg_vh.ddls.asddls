@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchasing Organization'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity Z_I_PURCHORG_VH
  as select from I_PurchasingOrganization

{
      @Search.defaultSearchElement: true
  key PurchasingOrganization,
      @Search.defaultSearchElement: true
      PurchasingOrganizationName,
      @Search.defaultSearchElement: true
      CompanyCode
}
