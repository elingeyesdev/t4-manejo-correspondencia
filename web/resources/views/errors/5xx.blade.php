@extends('errors.minimal')
@section('title', 'Servicio temporalmente no disponible')
@section('code', $exception->getStatusCode())
@section('message', 'Intenta nuevamente en unos minutos.')
