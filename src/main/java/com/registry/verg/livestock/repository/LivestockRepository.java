package com.registry.verg.livestock.repository;

import com.registry.verg.livestock.entity.LivestockEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LivestockRepository extends JpaRepository<LivestockEntity, String> {

}