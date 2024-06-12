package org.redhat.controller;

import java.util.HashMap;
import java.util.Map;

import javax.inject.Inject;
import javax.transaction.Transactional;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.resteasy.annotations.jaxrs.PathParam;
import org.redhat.model.Department;
import org.redhat.services.DepartmentService;
import org.redhat.services.BuildPipelineProxyService;
import org.redhat.services.OpsPipelineProxyService;
import org.redhat.services.AzurePipelineProxyService;
import org.redhat.services.PipelineProxyService;


import org.eclipse.microprofile.config.inject.ConfigProperty;


@Path("/department")
public class DepartmentController {
    @ConfigProperty(name = "pipeline.enabled" , defaultValue="true" )
    boolean pipelineEnabled;

    @Inject
    DepartmentService service;

    @Inject
    @RestClient
    PipelineProxyService pipelineProxyService;

    @Inject
    @RestClient
    OpsPipelineProxyService opsPipelineProxyService;

    @Inject
    @RestClient
    AzurePipelineProxyService azurePipelineProxyService;
    
    @Inject
    @RestClient
    BuildPipelineProxyService builsPipelineProxyService;

    @GET
    @Path("/")
    @Produces(MediaType.APPLICATION_JSON)
    public Department[] departments() {
        return service.getAll();
    }

    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    public Department department(@PathParam long id) {
        return service.getById(id);
    }

    @GET
    @Path("/status/{status}")
    @Produces(MediaType.APPLICATION_JSON)
    public Department[] getByStatus(@PathParam String status) {
        return service.getByStatus(status);
    }

    /**
     * trigger infrastrucutre provisioning on DC
     * @param department
     * @return
     */
    @POST
    @Path("/provision/trigger")
    @Produces(MediaType.APPLICATION_JSON)
    public void provisionTrigger(Department department) {
        if(pipelineEnabled){
            Map<String,String> payload = new HashMap<>();
            payload.put("department",department.getName());
            payload.put("action","provision");
            payload.put("location","dc");
            payload.put("type",department.getTenantType());
            pipelineProxyService.deploy(payload);
        }
    }
    /**
     * commit infrastrucutre provisioning on DC
     * @param department
     * @return
     */
    @POST
    @Path("/provision/commit")
    @Produces(MediaType.APPLICATION_JSON)
    public Department provision(Department department) {
        return service.provision(department);
    }

    /**
     * trigger infrastrucutre provisioning on cloud providers
     * @param department
     * @return
     */
    @POST
    @Path("/scale/trigger")
    @Consumes(MediaType.APPLICATION_JSON)  
    public void scaleTrigger(Department department) { 
        // trigger the pipeline
        // last step of the pipeline is to call /scale methods to update 
        // the db records accordingly
        if(pipelineEnabled){
            Map<String,String> payload = new HashMap<>();
            payload.put("department",department.getName());
            payload.put("action","provision");
            payload.put("location",department.getProvider());
            payload.put("type",department.getTenantType());
            pipelineProxyService.deploy(payload);
        }
    }

    /**
     * commit infrastrucutre provisioning on cloud providers
     * @param department
     * @return
     */
    @POST
    @Path("/scale/commit")
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)  
    public Department scale(Department department) { 
        return service.scale(department);
    }


    @POST
    @Path("/status")
    @Produces(MediaType.APPLICATION_JSON)
    public Department setStatus(Department department) {
        Department dep = service.setStatus(department);
        // trigger the pipeline
        if(pipelineEnabled && Department.PROVISIONED.equals( dep.getStatus())){
            Map<String,String> payload = new HashMap<>();
            payload.put("department",dep.getDescription());
            payload.put("action","deploy");
            payload.put("location","dc");
            pipelineProxyService.deploy(payload);
        }
        return dep;
    }

    @POST
    @Path("/azure")
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)    
    public Department azure(Map<String,String> system) {
        // trigger the equipment pipeline
        Map<String,String> payload = new HashMap<String,String>();
        payload.put("department",system.get("department"));
        payload.put("action","deploy");
        if(pipelineEnabled){
            azurePipelineProxyService.deploy(payload);
            payload.put("status","deployed");
        }
        return service.deployOnAzure(system.get("department"));
    }



    @POST
    @Path("/build")
    @Produces(MediaType.APPLICATION_JSON)
    public Department build(Department department) {
        Department bat = Department.findById(department.id);
        Map<String,String> payload = new HashMap<>();
        payload.put("department",bat.getDescription());
        builsPipelineProxyService.build(payload);
        return bat;
    }



    @POST
    @Path("/onboard")
    @Produces(MediaType.TEXT_PLAIN)
    @Consumes(MediaType.TEXT_PLAIN)
    /**
     * Slack integration
     * @param body
     * @return
     */
    public String onboard(String body) {
        Map<String, String> paramMap = parseQueryString(body);
        String team = paramMap.get("text");
        Department bat = service.getByName(team);
        // trigger the pipeline
        Map<String,String> payload = new HashMap<>();
        payload.put("department",bat.getDescription());
        payload.put("department_id",bat.id.toString());
        payload.put("action","deploy");
        pipelineProxyService.deploy(payload);
        return "Success";
        
    }

   
    private static Map<String, String> parseQueryString(String query) {
        Map<String, String> paramMap = new HashMap<>();
        String[] pairs = query.split("&");
        for (String pair : pairs) {
            int idx = pair.indexOf("=");
            String key = pair.substring(0, idx);
            String value = pair.substring(idx + 1,pair.length()-1);
            paramMap.put(key, value);
        }
        return paramMap;
    }

}   
