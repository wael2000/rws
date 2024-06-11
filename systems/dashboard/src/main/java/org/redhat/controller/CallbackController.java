package org.redhat.controller;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;


import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;
import javax.websocket.OnClose;
import javax.websocket.OnError;
import javax.websocket.OnMessage;
import javax.websocket.OnOpen;
import javax.websocket.Session;
import javax.websocket.server.PathParam;
import javax.websocket.server.ServerEndpoint;

import org.jboss.logging.Logger;
import org.redhat.model.App;
import org.redhat.model.Department;
import org.redhat.services.DepartmentService;

import io.quarkus.scheduler.Scheduled;

@ServerEndpoint("/callback/{department}")  
@ApplicationScoped
public class CallbackController {
    private static final Logger LOG = Logger.getLogger(CallbackController.class);
    
    @Inject
    DepartmentService service;

    Map<Long, Session> sessions = new ConcurrentHashMap<>();
    
    Map<Long, Department> systems = new HashMap<>();
    Map<Long, Set<App>> apps = new HashMap<>();

    @OnOpen
    public void onOpen(Session session, @PathParam("department") Long department) {
        sessions.put(department, session);
    }

    @OnClose
    public void onClose(Session session, @PathParam("department") Long department) {
        sessions.remove(department);
    }

    @OnError
    public void onError(Session session, @PathParam("department") Long department, Throwable throwable) {
        sessions.remove(department);
        LOG.error("onError", throwable);
    }


    /* 
    @OnMessage
    public void onMessage(String message, @PathParam("battalion") String battalion) {
        broadcast();
    }*/
    
    @Scheduled(every="50s") 
    void ping() {
        sessions.keySet().forEach( k -> {
        System.out.println("ping->" + k );
        sessions.get(k).getAsyncRemote().sendObject("ping", result -> {
            if (result.getException() != null) {
                System.out.println("Unable to send message: " + result.getException());
            }
            });
        });
    }
    
    @Scheduled(every="10s") 
    void broadcast() {
        Map<Long, Department> updatedSystems = service.findSystemStatusByIds(sessions.keySet());
        if(systems.size()==0)
            systems.putAll(updatedSystems);
        else {
            updatedSystems.keySet().forEach( k -> {
                Department currentDepartment = systems.get(k);
                Department updatesDepartment = updatedSystems.get(k);
                String systemStatus = currentDepartment.getStatus();
                String updatedSystemStatus = updatesDepartment.getStatus();
                boolean dc = currentDepartment.isDc();
                boolean updatedDC = updatesDepartment.isDc();
                boolean aws = currentDepartment.isAws();
                boolean updatedAWS = updatesDepartment.isAws();
                boolean azure = currentDepartment.isAzure();
                boolean updatedAzure = updatesDepartment.isAzure();
                if(!updatedSystemStatus.equals(systemStatus) || 
                    dc!=updatedDC || aws!=updatedAWS || azure!=updatedAzure) {
                    systems.put(k, updatesDepartment);
                    String message = "d," + k ;
                    System.out.println("b-message: " + message);
                    sessions.get(k).getAsyncRemote().sendObject(message, result -> {
                    if (result.getException() != null) {
                        System.out.println("Unable to send message: " + result.getException());
                    }
                    });
                }
                /* 
                if( apps.get(k)==null)
                    apps.put(k, service.getById(k).getApplications());
                else {
                    Set<App> newAppList = service.getById(k).getApplications();
                    Set<App> currenAppList = apps.get(k);
                    newAppList.forEach(app -> {
                        App existingApp = currenAppList.getById(app.id);
                        if(app.isDeployed()!=existingApp.isDeployed()){
                            sessions.get(k).getAsyncRemote().sendObject(app, result -> {
                                if (result.getException() != null) {
                                    System.out.println("Unable to send message: " + result.getException());
                                }
                                });
                        }
                        
                    });
                    apps.put(k, newAppList); 
                }*/
            }); 
            systems.putAll(updatedSystems);
        }
    }
    
}
