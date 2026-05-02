@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company Code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true

define view entity Z_I_CompanyCodeVH
  as select from I_CompanyCode
{
      @Search.defaultSearchElement: true
  key CompanyCode,
      @Search.defaultSearchElement: true
      CompanyCodeName
}
