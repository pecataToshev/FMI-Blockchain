// SPDX-License-Identifier: GPL-3.0

pragma solidity >= 0.7.0;

// import "@nomiclabs/buidler/console.sol";
import "hardhat/console.sol";

struct VaccinationRecord {
    string vaccine;
    uint256 timestamp;
}

struct PatientRecord {
    string name;
    bool hasRequestedVaccination;
    VaccinationRecord[] records;
}

struct VaccineData {

}


contract VaccineRegistry {

    address public trustedAuthority;

    mapping (string => VaccineData) approvedVaccines;
    mapping (address => bool) public vaccinationCenters;
    mapping (address => PatientRecord) public patientRecords;

    constructor() {
        trustedAuthority = msg.sender;
        addVaccine("a"), addVaccine("b"), addVaccine("c");
    }

    function register(string memory name) public {
        require(!isRegistered(msg.sender), "Already registered!");
        patientRecords[msg.sender].name = name;
    }

    function requestVaccination() public {
        require(isRegistered(msg.sender), "Patient not registered!");
        require(!patientRecords[msg.sender].hasRequestedVaccination , "Already requested!");
        patientRecords[msg.sender].hasRequestedVaccination = true;
    }

    function vaccinate(address patient, string memory vaccineName) public {
        require(vaccinationCenters[msg.sender], "Unauthorized vaccination center!");
        require(approvedVaccines[vaccineName], "Unapproved vaccine!");
        require(isRegistered(patient), "Patient not registered!");
        require(patientRecords[patient].hasRequestedVaccination , "Patient has not requested a vaccine!");
        
        patientRecords[patient].records.push(VaccinationRecord(vaccineName, block.timestamp););
        
        // uint len = patientRecords[patient].records.length;
        // console.log(patientRecords[patient].records[len - 1].vaccine);
    }
    
    function addVaccinationCenter(address center) public {
        require(msg.sender == trustedAuthority, "Sender not authorized to add centers!");
        vaccinationCenters[center] = true;
    }

    function addVaccine(string memory vaccineName) public {
        require(msg.sender == trustedAuthority, "Sender not authorized to add vaccine!");
        approvedVaccines[vaccineName] = true;
    }

    // metod goden za vaksinaciq???

    function isRegistered(address patient) public returns (bool) {
        return patientRecords[patient] == address(0x0);
        // return bytes(patientRecords[patient].name).length > 0;
    }
}