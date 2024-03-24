package com.profit4cloud.springboottour.Student;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class StudentController {


    @GetMapping
    public String getStudents() {
        return "Hello, students";
    }
}
