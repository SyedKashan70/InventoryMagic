public with sharing class LwcLookupController {
    @AuraEnabled(cacheable=true)  
    public static List<sobject> findRecordsWithFilters(String searchKey, String objectName, String queryFields , String queryFilters, String orderByFieldsWithOrder,  Integer recordLimit,Boolean searchFromStart,String wildCard) {
      
      try {
        string query = 'SELECT Id, Name ';

        //Add Query Fields
        if(QueryFields != null && !String.isBlank(QueryFields)) {
          query += ', ' + QueryFields;
        }

        query += ' FROM ' + objectName;

        String searchText = '\'%' + String.escapeSingleQuotes(searchKey) + '%\'';
        if(searchFromStart) {
          searchText = '\'' + String.escapeSingleQuotes(searchKey) + '%\'';
        }
        query += ' WHERE '   + wildCard + ' LIKE '+searchText;
        if(QueryFilters != null && !String.isBlank(QueryFilters)) {
          query += ' AND ';
          query += QueryFilters;
        }

        // if(filterIds != null && !filterIds.isEmpty()) {
        //   query += ' AND Id IN :filterIds ';
        // }

        if(OrderByFieldsWithOrder != null && !String.isBlank(OrderByFieldsWithOrder)) {
          query += ' ORDER BY ';
          query += OrderByFieldsWithOrder;
        }

        if(recordLimit != null && recordLimit > 0) {
          query += ' LIMIT ' + recordLimit;
        }
        System.debug('Query in lwc lookup '+ query);
        return Database.query(query);
      }
      catch(Exception ex) {
        System.debug('LWC Lookupcontroller Failed Error => '+ex.getMessage());
        throw new AuraHandledException(ex.getMessage());
      }

    }
}