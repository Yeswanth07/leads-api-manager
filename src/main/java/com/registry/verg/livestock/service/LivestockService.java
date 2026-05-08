package com.registry.verg.livestock.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.registry.verg.core.dto.CustomResponse;
import com.registry.verg.core.elasticsearch.dto.SearchCriteria;


public interface LivestockService {

    CustomResponse createLivestock(JsonNode livestockEntity);

    CustomResponse searchLivestock(SearchCriteria searchCriteria);

    CustomResponse assignLivestock(JsonNode livestockEntity, String token);

    CustomResponse read(String id);

    CustomResponse delete(String id);
}